// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";

contract TradeService is ITradeService {
  // struct
  struct DecreasePositionVars {
    uint256 absPositionSizeE30;
    uint256 priceE30;
    int256 currentPositionSizeE30;
    bool isLongPosition;
  }

  // events
  // todo: modify event parameters
  event LogDecreasePosition(
    bytes32 indexed _positionId,
    uint256 _decreasedSize
  );

  // state
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public calculator;
  address public oracle;

  constructor(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _calculator,
    address _oracle
  ) {
    // todo: sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = _calculator;
    oracle = _oracle;
  }

  function increasePosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external {
    // get the sub-account from the primary account and sub-account ID
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    bytes32 _posId = _getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_posId);

    // get the market configuration for the given market index
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    // check size delta
    if (_sizeDelta == 0) revert ITradeService_BadSizeDelta();

    // check allow increase position
    if (!_marketConfig.allowIncreasePosition)
      revert ITradeService_NotAllowIncrease();

    // determine whether the new size delta is for a long position
    bool _isLong = _sizeDelta > 0;

    bool _isNewPosition = _position.positionSizeE30 == 0;

    // Pre validation
    // Verify that the number of positions has exceeds
    {
      // get the trading configuration.
      IConfigStorage.TradingConfig memory _tradingConfig = IConfigStorage(
        configStorage
      ).getTradingConfig();

      if (
        _isNewPosition &&
        _tradingConfig.maxPosition <
        IPerpStorage(perpStorage).getNumberOfSubAccountPosition(_subAccount) + 1
      ) revert ITradeService_BadNumberOfPosition();
    }

    bool _currentPositionIsLong = _position.positionSizeE30 > 0;
    // Verify that the current position has the same exposure direction
    if (!_isNewPosition && _currentPositionIsLong != _isLong)
      revert ITradeService_BadExposure();

    // Get Price market.
    uint256 _priceE30;
    // market validation
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;
      (_priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          _isLong, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold,
          0
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check price stale for 30 seconds
      // todo: do it as config, and fix related testcase
      if (block.timestamp - _lastPriceUpdated > 30)
        revert ITradeService_PriceStale();
    }

    // get the absolute value of the new size delta
    uint256 _absSizeDelta = abs(_sizeDelta);

    // if the position size is zero, set the average price to the current price (new position)
    if (_isNewPosition) {
      _position.avgEntryPriceE30 = _priceE30;
      _position.primaryAccount = _primaryAccount;
      _position.subAccountId = _subAccountId;
      _position.marketIndex = _marketIndex;
    }

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (!_isNewPosition) {
      _position.avgEntryPriceE30 = getPositionNextAveragePrice(
        _marketIndex,
        abs(_position.positionSizeE30),
        _isLong,
        _absSizeDelta,
        _position.avgEntryPriceE30,
        _priceE30
      );
    }

    // TODO: Collect trading fee, borrowing fee, update borrowing rate, collect funding fee, and update funding rate.

    // update the position size by adding the new size delta
    _position.positionSizeE30 += _sizeDelta;

    // if the position size is zero after the update, revert the transaction with an error
    if (_position.positionSizeE30 == 0) revert ITradeService_BadPositionSize();

    // calculate the initial margin required for the new position
    uint256 _imr = (_absSizeDelta * _marketConfig.initialMarginFraction) / 1e18;

    {
      // get the amount of free collateral available for the sub-account
      uint256 subAccountFreeCollateral = ICalculator(calculator)
        .getFreeCollateral(_subAccount);
      // if the free collateral is less than the initial margin required, revert the transaction with an error
      if (subAccountFreeCollateral < _imr)
        revert ITradeService_InsufficientFreeCollateral();
    }

    {
      // calculate the maximum amount of reserve required for the new position
      uint256 _maxReserve = (_imr * _marketConfig.maxProfitRate) / 1e18;
      // increase the reserved amount by the maximum reserve required for the new position
      increaseReserved(_maxReserve);
      _position.reserveValueE30 += _maxReserve;
    }

    // get the global market for the given market index
    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
      .getGlobalMarketByIndex(_marketIndex);

    {
      // calculate the change in open interest for the new position
      uint256 _changedOpenInterest = (_absSizeDelta * 1e30) / _priceE30; // TODO: use decimal asset
      _position.openInterest += _changedOpenInterest;
      // update gobal market state
      if (_isLong) {
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize + _absSizeDelta,
          _globalMarket.longAvgPrice, // todo: recalculate arg price
          _globalMarket.longOpenInterest + _changedOpenInterest
        );
      } else {
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize + _absSizeDelta,
          _globalMarket.shortAvgPrice, // todo: recalculate arg price
          _globalMarket.shortOpenInterest + _changedOpenInterest
        );
      }
    }

    // save the updated position to the storage
    IPerpStorage(perpStorage).savePosition(_subAccount, _posId, _position);
  }

  // todo: rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketIndex - market index
  /// @param _positionSizeE30ToDecrease - position size to decrease
  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease
  ) external {
    // prepare
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);

    address _subAccount = _getSubAccount(_account, _subAccountId);
    bytes32 _positionId = _getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_positionId);

    // init vars
    DecreasePositionVars memory vars = DecreasePositionVars({
      absPositionSizeE30: 0,
      priceE30: 0,
      currentPositionSizeE30: 0,
      isLongPosition: false
    });

    // =========================================
    // | ---------- pre validation ----------- |
    // =========================================

    // if position size is 0 means this position is already closed
    vars.currentPositionSizeE30 = _position.positionSizeE30;
    if (vars.currentPositionSizeE30 == 0)
      revert ITradeService_PositionAlreadyClosed();

    vars.isLongPosition = vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    vars.absPositionSizeE30 = uint256(
      vars.isLongPosition
        ? vars.currentPositionSizeE30
        : -vars.currentPositionSizeE30
    );

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > vars.absPositionSizeE30)
      revert ITradeService_DecreaseTooHighPositionSize();

    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      // todo: update code to use normal get latest price, there is validate price
      (vars.priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(
        oracle
      ).unsafeGetLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          !vars.isLongPosition, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check price stale for 30 seconds
      // todo: do it as config, and fix related testcase
      if (block.timestamp - _lastPriceUpdated > 30)
        revert ITradeService_PriceStale();

      // check sub account is healty
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr)
        revert ITradeService_SubAccountEquityIsUnderMMR();
    }

    // todo: update funding & borrowing fee rate
    // todo: calculate trading, borrowing and funding fee
    // todo: collect fee

    // =========================================
    // | ------ update perp storage ---------- |
    // =========================================
    uint256 _newAbsPositionSizeE30 = vars.absPositionSizeE30 -
      _positionSizeE30ToDecrease;

    // check position is too tiny
    // todo: now validate this at 1 USD, design where to keep this config
    //       due to we has problem stack too deep in MarketConfig now
    if (_newAbsPositionSizeE30 > 0 && _newAbsPositionSizeE30 < 1e30)
      revert ITradeService_TooTinyPosition();

    {
      uint256 _openInterestDelta = (_position.openInterest *
        _positionSizeE30ToDecrease) / vars.absPositionSizeE30;

      // update position info
      IPerpStorage(perpStorage).updatePositionById(
        _positionId,
        vars.isLongPosition
          ? int256(_newAbsPositionSizeE30)
          : -int256(_newAbsPositionSizeE30), // todo: optimized
        // new position size * IMF * max profit rate
        (((_newAbsPositionSizeE30 * _marketConfig.initialMarginFraction) /
          1e18) * _marketConfig.maxProfitRate) / 1e18,
        _position.avgEntryPriceE30,
        _position.openInterest - _openInterestDelta
      );

      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
        .getGlobalMarketByIndex(_marketIndex);

      if (vars.isLongPosition) {
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.longAvgPrice, // todo: recalculate arg price
          _globalMarket.longOpenInterest - _openInterestDelta
        );
      } else {
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.shortAvgPrice, // todo: recalculate arg price
          _globalMarket.shortOpenInterest - _openInterestDelta
        );
      }
      IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage)
        .getGlobalState();

      // update global storage
      // to calculate new global reserve = current global reserve - reserve delta (position reserve * (position size delta / current position size))
      IPerpStorage(perpStorage).updateGlobalState(
        _globalState.reserveValueE30 -
          ((_position.reserveValueE30 * _positionSizeE30ToDecrease) /
            vars.absPositionSizeE30)
      );
    }

    // =========================================
    // | ------- settlement position --------- |
    // =========================================
    // todo: settle profit & loss

    // =========================================
    // | --------- post validation ----------- |
    // =========================================
    {
      // check sub account is healty
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr)
        revert ITradeService_SubAccountEquityIsUnderMMR();
    }

    emit LogDecreasePosition(_positionId, _positionSizeE30ToDecrease);
  }

  // todo: add description
  function _getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address) {
    if (_subAccountId > 255) revert ITradeService_BadSubAccountId();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // todo: add description
  function _getPositionId(
    address _account,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  /// @notice Calculates the next average price of a position, given the current position details and the next price.
  /// @param marketIndex The index of the market.
  /// @param size The current size of the position.
  /// @param isLong Whether the position is long or short.
  /// @param sizeDelta The size difference between the current position and the next position.
  /// @param averagePrice The current average price of the position.
  /// @param nextPrice The next price of the position.
  /// @return The next average price of the position.
  function getPositionNextAveragePrice(
    uint256 marketIndex,
    uint256 size,
    bool isLong,
    uint256 sizeDelta,
    uint256 averagePrice,
    uint256 nextPrice
  ) internal view returns (uint256) {
    // Get the delta and isProfit value from the getDelta function
    (bool isProfit, uint256 delta) = getDelta(
      marketIndex,
      size,
      isLong,
      averagePrice
    );
    // Calculate the next size and divisor
    uint256 nextSize = size + sizeDelta;
    uint256 divisor;
    if (isLong) {
      divisor = isProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = isProfit ? nextSize - delta : nextSize + delta;
    }

    // Calculate the next average price of the position
    return (nextPrice * nextSize) / divisor;
  }

  /// @notice Calculates the delta between average price and mark price, based on the size of position and whether the position is profitable.
  /// @param _marketIndex The
  /// @param _size The size of the position.
  /// @param _isLong The
  /// @param _averagePrice The average price of the position.
  /// @return isProfit A boolean value indicating whether the position is profitable or not.
  /// @return delta The Profit between the average price and the fixed price, adjusted for the size of the order.
  function getDelta(
    uint256 _marketIndex,
    uint256 _size,
    bool _isLong,
    uint256 _averagePrice
  ) public view returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (_averagePrice == 0) revert ITradeService_InvalidAveragePrice();

    // Get Price market.
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigByIndex(_marketIndex);
    (uint256 price, ) = IOracleMiddleware(oracle).getLatestPrice(
      marketConfig.assetId,
      _isLong,
      marketConfig.priceConfidentThreshold,
      0
    );

    // Calculate the difference between the average price and the fixed price.
    uint256 priceDelta;
    unchecked {
      priceDelta = _averagePrice > price
        ? _averagePrice - price
        : price - _averagePrice;
    }

    // Calculate the delta, adjusted for the size of the order.
    uint256 delta = (_size * priceDelta) / _averagePrice;

    // Determine if the position is profitable or not based on the averagePrice and the mark price.
    bool isProfit;
    if (_isLong) {
      isProfit = price > _averagePrice;
    } else {
      isProfit = price < _averagePrice;
    }

    // Return the values of isProfit and delta.
    return (isProfit, delta);
  }

  /// @notice This function increases the reserve value
  /// @param reservedValue The amount by which to increase the reserve value.
  function increaseReserved(uint256 reservedValue) internal {
    // Get the total TVL
    uint256 tvl = ICalculator(calculator).getPLPValueE30(true);

    // Retrieve the global state
    IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage)
      .getGlobalState();

    // get the liquidity configuration
    IConfigStorage.LiquidityConfig memory _liquidityConfig = IConfigStorage(
      configStorage
    ).getLiquidityConfig();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += reservedValue;

    // Check if the new reserve value exceeds the % of AUM, and revert if it does
    if (
      (tvl * _liquidityConfig.maxPLPUtilization) / 1e18 <
      _globalState.reserveValueE30
    ) {
      revert ITradeService_InsufficientLiquidity();
    }

    // Update the new reserve value in the IPerpStorage contract
    IPerpStorage(perpStorage).updateReserveValue(_globalState.reserveValueE30);
  }

  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
