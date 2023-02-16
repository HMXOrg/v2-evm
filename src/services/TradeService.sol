// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";

contract TradeService is ITradeService {
  address perpStorage;
  address vaultStorage;
  address configStorage;
  address calculator;
  address public oracle;

  constructor(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _calculator,
    address _oracle
  ) {
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
    address _subAccount = getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    bytes32 _posId = getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_posId);

    // get the market configuration for the given market index
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigs(_marketIndex);

    // determine whether the new size delta is for a long position
    bool _isLong = _sizeDelta > 0;

    bool _isNewPosition = _position.sizeE30 == 0;

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
    // Verify that the current position has the same exposure direction
    if (!_isNewPosition && ((_position.sizeE30 > 0) == _isLong))
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
          _marketConfig.priceConfidentThreshold
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is 1, means that oracle couldn't get price from pyth
      if (_marketStatus == 1) revert ITradeService_MarketIsClosed();

      // check price stale for 30 seconds
      // todo: do it as config, and fix related testcase
      if (block.timestamp - _lastPriceUpdated > 30)
        revert ITradeService_PriceStale();
    }

    // TODO: Validate AllowIncreasePosition

    // if the position size is zero, set the average price to the current price (new position)
    if (_position.sizeE30 == 0) {
      _position.avgPriceE30 = _priceE30;
    }

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (_position.sizeE30 != 0 && _sizeDelta != 0) {
      _position.avgPriceE30 = getPositionNextAveragePrice(
        _marketIndex,
        _position.sizeE30,
        _isLong,
        _sizeDelta,
        _position.avgPriceE30,
        _priceE30
      );
    }

    // TODO: Collect trading fee, borrowing fee, update borrowing rate, collect funding fee, and update funding rate.

    // update the position size by adding the new size delta
    _position.sizeE30 += _sizeDelta;

    // if the position size is zero after the update, revert the transaction with an error
    if (_position.sizeE30 == 0) revert ITradeService_BadPositionSize();

    // get the absolute value of the new size delta
    uint256 _absSizeDelta = abs(_sizeDelta);

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
    }

    // save the updated position to the storage
    IPerpStorage(perpStorage).savePosition(_posId, _position);

    // get the global market for the given market index
    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
      .getGlobalMarketById(_marketIndex);

    {
      // calculate the change in open interest for the new position
      uint256 _changedOpenInterest = (_absSizeDelta * 1e30) / _priceE30;
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
  }

  function getPositionId(
    address _account,
    uint256 _marketId
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketId));
  }

  function getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address) {
    if (_subAccountId > 255) revert ITradeService_BadSubAccountId();
    return address(uint160(_primary) ^ uint160(_subAccountId));
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
    int256 size,
    bool isLong,
    int256 sizeDelta,
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
    uint256 nextSize = abs(size + sizeDelta);
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
    int256 _size,
    bool _isLong,
    uint256 _averagePrice
  ) public view returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (_averagePrice == 0) revert ITradeService_InvalidAveragePrice();

    // Get Price market.
    IConfigStorage.MarketConfig memory marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigs(_marketIndex);
    (uint256 price, ) = IOracleMiddleware(oracle).getLatestPrice(
      marketConfig.assetId,
      _isLong,
      marketConfig.priceConfidentThreshold
    );

    // Calculate the difference between the average price and the fixed price.
    uint256 priceDelta;
    unchecked {
      priceDelta = _averagePrice > price
        ? _averagePrice - price
        : price - _averagePrice;
    }

    // Calculate the delta, adjusted for the size of the order.
    uint256 delta = (abs(_size) * priceDelta) / _averagePrice;

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
    // Get the total AUM
    uint256 aum = ICalculator(calculator).getAum();

    // Retrieve the global state
    IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage)
      .getGlobalState();

    // // get the liquidity configuration
    IConfigStorage.LiquidityConfig memory _liquidityConfig = IConfigStorage(
      configStorage
    ).getLiquidityConfig();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += reservedValue;

    // Check if the new reserve value exceeds the % of AUM, and revert if it does
    if (
      (aum * _liquidityConfig.maxPLPUtilization) / 1e18 <
      _globalState.reserveValueE30
    ) {
      revert ITradeService_InsufficientLiquidity();
    }
    // TODO: validate Max PLP Utilization

    // Update the new reserve value in the IPerpStorage contract
    IPerpStorage(perpStorage).updateReserveValue(_globalState.reserveValueE30);
  }

  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
