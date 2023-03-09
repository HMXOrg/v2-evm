// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contracts
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { FeeCalculator } from "@hmx/contracts/FeeCalculator.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";

// @todo - refactor, deduplicate code
contract TradeService is ReentrancyGuard, ITradeService {
  uint32 internal constant BPS = 1e4;
  uint64 internal constant RATE_PRECISION = 1e18;

  /**
   * Structs
   */
  struct IncreasePositionVars {
    PerpStorage.Position position;
    address subAccount;
    bytes32 positionId;
    bool isLong;
    bool isNewPosition;
    bool currentPositionIsLong;
    uint256 priceE30;
    int32 exponent;
  }
  struct DecreasePositionVars {
    PerpStorage.Position position;
    address subAccount;
    bytes32 positionId;
    uint256 absPositionSizeE30;
    uint256 avgEntryPriceE30;
    uint256 priceE30;
    int256 currentPositionSizeE30;
    bool isLongPosition;
    uint256 positionSizeE30ToDecrease;
    address tpToken;
    uint256 limitPriceE30;
    // for SLOAD
    Calculator calculator;
    PerpStorage perpStorage;
    ConfigStorage configStorage;
  }

  struct SettleLossVars {
    uint256 price;
    uint256 collateral;
    uint256 collateralUsd;
    uint256 collateralToRemove;
    uint256 decimals;
    bytes32 tokenAssetId;
  }

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /**
   * Events
   */
  // @todo - modify event parameters
  event LogDecreasePosition(bytes32 indexed _positionId, uint256 _decreasedSize);

  event LogCollectTradingFee(address account, uint8 assetClass, uint256 feeUsd);

  event LogCollectBorrowingFee(address account, uint8 assetClass, uint256 feeUsd);

  event LogCollectFundingFee(address account, uint8 assetClass, int256 feeUsd);

  event LogForceClosePosition(
    address indexed _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    uint256 _closedPositionSize,
    bool isProfit,
    uint256 _delta
  );

  event LogDeleverage(
    address indexed _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    uint256 _closedPositionSize
  );

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  Calculator public calculator; // cache this from configStorage

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = Calculator(ConfigStorage(_configStorage).calculator());
  }

  function reloadConfig() external {
    // TODO: access control, sanity check, natspec
    // TODO: discuss about this pattern

    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /// @notice This function increases a trader's position for a specific market by a given size delta.
  ///         The primary account and sub-account IDs are used to identify the trader's account.
  ///         The market index is used to identify the specific market.
  /// @param _primaryAccount The address of the primary account associated with the trader.
  /// @param _subAccountId The ID of the sub-account associated with the trader.
  /// @param _marketIndex The index of the market for which the position is being increased.
  /// @param _sizeDelta The change in size of the position. Positive values meaning LONG position, while negative values mean SHORT position.
  /// @param _limitPriceE30 limit price for execute order
  function increasePosition(
    address _primaryAccount,
    uint8 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _limitPriceE30
  ) external nonReentrant onlyWhitelistedExecutor {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    Calculator _calculator = calculator;
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // validate service should be called from handler ONLY
    _configStorage.validateServiceExecutor(address(this), msg.sender);

    IncreasePositionVars memory _vars;

    // get the sub-account from the primary account and sub-account ID
    _vars.subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _perpStorage.getPositionById(_vars.positionId);

    // get the market configuration for the given market index
    ConfigStorage.MarketConfig memory _marketConfig = _configStorage.getMarketConfigByIndex(_marketIndex);

    // check size delta
    if (_sizeDelta == 0) revert ITradeService_BadSizeDelta();

    // check allow increase position
    if (!_marketConfig.allowIncreasePosition) revert ITradeService_NotAllowIncrease();

    // determine whether the new size delta is for a long position
    _vars.isLong = _sizeDelta > 0;

    _vars.isNewPosition = _vars.position.positionSizeE30 == 0;

    // Pre validation
    // Verify that the number of positions has exceeds
    {
      if (
        _vars.isNewPosition &&
        _configStorage.getTradingConfig().maxPosition < _perpStorage.getNumberOfSubAccountPosition(_vars.subAccount) + 1
      ) revert ITradeService_BadNumberOfPosition();
    }

    _vars.currentPositionIsLong = _vars.position.positionSizeE30 > 0;
    // Verify that the current position has the same exposure direction
    if (!_vars.isNewPosition && _vars.currentPositionIsLong != _vars.isLong) revert ITradeService_BadExposure();

    // Update borrowing rate
    updateBorrowingRate(_marketConfig.assetClass, _limitPriceE30, _marketConfig.assetId);

    // Update funding rate
    updateFundingRate(_marketIndex, _limitPriceE30);

    // get the global market for the given market index
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      // Get Price market.
      (_vars.priceE30, _vars.exponent, _lastPriceUpdated, _marketStatus) = OracleMiddleware(_configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _vars.isLong, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          _sizeDelta,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      _vars.priceE30 = _limitPriceE30 != 0 ? _limitPriceE30 : _vars.priceE30;

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();
    }

    // market validation
    // check sub account equity is under MMR
    _subAccountHealthCheck(_vars.subAccount, _limitPriceE30, _marketConfig.assetId);

    // get the absolute value of the new size delta
    uint256 _absSizeDelta = abs(_sizeDelta);

    // if the position size is zero, set the average price to the current price (new position)
    if (_vars.isNewPosition) {
      _vars.position.avgEntryPriceE30 = _vars.priceE30;
      _vars.position.primaryAccount = _primaryAccount;
      _vars.position.subAccountId = _subAccountId;
      _vars.position.marketIndex = _marketIndex;
    }

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (!_vars.isNewPosition) {
      _vars.position.avgEntryPriceE30 = _getPositionNextAveragePrice(
        abs(_vars.position.positionSizeE30),
        _vars.isLong,
        _absSizeDelta,
        _vars.priceE30,
        _vars.position.avgEntryPriceE30
      );
    }

    // MarginFee = Trading Fee + Borrowing Fee
    collectMarginFee(
      _vars.subAccount,
      _absSizeDelta,
      _marketConfig.assetClass,
      _vars.position.reserveValueE30,
      _vars.position.entryBorrowingRate,
      _marketConfig.increasePositionFeeRateBPS
    );

    settleMarginFee(_vars.subAccount);

    // Collect funding fee
    collectFundingFee(
      _vars.subAccount,
      _marketConfig.assetClass,
      _marketIndex,
      _vars.position.positionSizeE30,
      _vars.position.entryFundingRate
    );

    settleFundingFee(_vars.subAccount, _limitPriceE30, _marketConfig.assetId);

    // update the position size by adding the new size delta
    _vars.position.positionSizeE30 += _sizeDelta;

    {
      PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(
        _marketConfig.assetClass
      );

      _vars.position.entryBorrowingRate = _globalAssetClass.sumBorrowingRate;
      _vars.position.entryFundingRate = _globalMarket.currentFundingRate;
    }

    // if the position size is zero after the update, revert the transaction with an error
    if (_vars.position.positionSizeE30 == 0) revert ITradeService_BadPositionSize();

    {
      // calculate the initial margin required for the new position
      uint256 _imr = (_absSizeDelta * _marketConfig.initialMarginFractionBPS) / BPS;

      // get the amount of free collateral available for the sub-account
      uint256 subAccountFreeCollateral = _calculator.getFreeCollateral(
        _vars.subAccount,
        _vars.priceE30,
        _marketConfig.assetId
      );
      // if the free collateral is less than the initial margin required, revert the transaction with an error
      if (subAccountFreeCollateral < _imr) revert ITradeService_InsufficientFreeCollateral();

      // calculate the maximum amount of reserve required for the new position
      uint256 _maxReserve = (_imr * _marketConfig.maxProfitRateBPS) / BPS;
      // increase the reserved amount by the maximum reserve required for the new position
      _increaseReserved(_marketConfig.assetClass, _maxReserve, _limitPriceE30, _marketConfig.assetId);
      _vars.position.reserveValueE30 += _maxReserve;
    }

    {
      // calculate the change in open interest for the new position
      uint256 _changedOpenInterest = (_absSizeDelta * (10 ** uint32(-_vars.exponent))) / _vars.priceE30;

      _vars.position.openInterest += _changedOpenInterest;
      _vars.position.lastIncreaseTimestamp = block.timestamp;

      // update global market state
      if (_vars.isLong) {
        uint256 _nextAvgPrice = _globalMarket.longPositionSize == 0
          ? _vars.priceE30
          : _calculator.calculateLongAveragePrice(_globalMarket, _vars.priceE30, _sizeDelta, 0);

        _perpStorage.updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize + _absSizeDelta,
          _nextAvgPrice,
          _globalMarket.longOpenInterest + _changedOpenInterest
        );
      } else {
        // to increase SHORT position sizeDelta should be negative
        uint256 _nextAvgPrice = _globalMarket.shortPositionSize == 0
          ? _vars.priceE30
          : _calculator.calculateShortAveragePrice(_globalMarket, _vars.priceE30, _sizeDelta, 0);

        _perpStorage.updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize + _absSizeDelta,
          _nextAvgPrice,
          _globalMarket.shortOpenInterest + _changedOpenInterest
        );
      }
    }

    // save the updated position to the storage
    _perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);
  }

  // @todo - rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketIndex - market index
  /// @param _positionSizeE30ToDecrease - position size to decrease
  /// @param _tpToken - take profit token
  /// @param _limitPriceE30  price from LimitTrade in e30 unit
  function decreasePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken,
    uint256 _limitPriceE30
  ) external nonReentrant onlyWhitelistedExecutor {
    // init vars
    DecreasePositionVars memory _vars;
    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.calculator = calculator;

    // validate service should be called from handler ONLY
    _vars.configStorage.validateServiceExecutor(address(this), msg.sender);

    // prepare
    ConfigStorage.MarketConfig memory _marketConfig = _vars.configStorage.getMarketConfigByIndex(_marketIndex);

    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);

    // Pre validation
    // if position size is 0 means this position is already closed
    _vars.currentPositionSizeE30 = _vars.position.positionSizeE30;
    if (_vars.currentPositionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.currentPositionSizeE30 : -_vars.currentPositionSizeE30
    );
    _vars.positionSizeE30ToDecrease = _positionSizeE30ToDecrease;
    _vars.tpToken = _tpToken;
    _vars.limitPriceE30 = _limitPriceE30;

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > _vars.absPositionSizeE30) revert ITradeService_DecreaseTooHighPositionSize();

    PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_marketIndex);
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      (_vars.priceE30, , _lastPriceUpdated, _marketStatus) = OracleMiddleware(_vars.configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          _vars.isLongPosition ? -int(_positionSizeE30ToDecrease) : int(_positionSizeE30ToDecrease),
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      _vars.priceE30 = _limitPriceE30 != 0 ? _limitPriceE30 : _vars.priceE30;

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check sub account equity is under MMR
      _subAccountHealthCheck(_vars.subAccount, _limitPriceE30, _marketConfig.assetId);
    }

    // update position, market, and global market state
    _decreasePosition(_marketConfig, _marketIndex, _vars);
  }

  // @todo - access control
  /// @notice force close trader position with maximum profit could take
  /// @param _account position owner
  /// @param _subAccountId sub-account id
  /// @param _marketIndex position market index
  /// @param _tpToken take profit token
  function forceClosePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken
  ) external nonReentrant onlyWhitelistedExecutor returns (bool _isMaxProfit, bool _isProfit, uint256 _delta) {
    // init vars
    DecreasePositionVars memory _vars;

    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = calculator;
    _vars.perpStorage = PerpStorage(perpStorage);

    ConfigStorage.MarketConfig memory _marketConfig = _vars.configStorage.getMarketConfigByIndex(_marketIndex);

    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);

    // Pre validation
    // if position size is 0 means this position is already closed
    _vars.currentPositionSizeE30 = _vars.position.positionSizeE30;
    if (_vars.currentPositionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.currentPositionSizeE30 : -_vars.currentPositionSizeE30
    );
    _vars.positionSizeE30ToDecrease = _vars.absPositionSizeE30;
    _vars.tpToken = _tpToken;

    PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_marketIndex);

    {
      uint8 _marketStatus;

      (_vars.priceE30, , , _marketStatus) = OracleMiddleware(_vars.configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longOpenInterest) - int(_globalMarket.shortOpenInterest)),
          -_vars.currentPositionSizeE30,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketConfig.active && _marketStatus != 2) revert ITradeService_MarketIsClosed();
      // check sub account equity is under MMR
      /// @dev no need to derived price on this
      _subAccountHealthCheck(_vars.subAccount, 0, 0);
    }

    // update position, market, and global market state
    /// @dev no need to derived price on this
    (_isMaxProfit, _isProfit, _delta) = _decreasePosition(_marketConfig, _marketIndex, _vars);

    emit LogForceClosePosition(
      _account,
      _subAccountId,
      _marketIndex,
      _tpToken,
      _vars.absPositionSizeE30,
      _isProfit,
      _delta
    );
  }

  /// @notice Validates if a market is delisted.
  /// @param _marketIndex The index of the market to be checked.
  function validateMarketDelisted(uint256 _marketIndex) external view {
    // Check if the market is currently active in the config storage
    if (ConfigStorage(configStorage).getMarketConfigByIndex(_marketIndex).active) {
      // If it's active, revert with a custom error message defined in the ITradeService_MarketHealthy error definition
      revert ITradeService_MarketHealthy();
    }
  }

  /// @notice This function validates if deleverage is safe and healthy in Pool liquidity provider.
  function validateDeleverage() external view {
    // SLOAD
    Calculator _calculator = calculator;
    uint256 _aum = _calculator.getAUME30(false, 0, 0);
    uint256 _tvl = _calculator.getPLPValueE30(false, 0, 0);

    // check plp safety buffer
    if ((_tvl - _aum) * BPS <= (BPS - ConfigStorage(configStorage).getLiquidityConfig().plpSafetyBufferBPS) * _tvl)
      revert ITradeService_PlpHealthy();
  }

  /// @notice Validates if close position with max profit.
  /// @param _isMaxProfit close position with max profit.
  function validateMaxProfit(bool _isMaxProfit) external pure {
    if (!_isMaxProfit) revert ITradeService_ReservedValueStillEnough();
  }

  /// @notice decrease trader position
  /// @param _marketConfig - target market config
  /// @param _globalMarketIndex - global market index
  /// @param _vars - decrease criteria
  /// @return _isMaxProfit - positiion is close with max profit
  function _decreasePosition(
    ConfigStorage.MarketConfig memory _marketConfig,
    uint256 _globalMarketIndex,
    DecreasePositionVars memory _vars
  ) internal returns (bool _isMaxProfit, bool isProfit, uint256 delta) {
    // Update borrowing rate
    updateBorrowingRate(_marketConfig.assetClass, _vars.limitPriceE30, _marketConfig.assetId);

    // Update funding rate
    updateFundingRate(_globalMarketIndex, _vars.limitPriceE30);

    collectMarginFee(
      _vars.subAccount,
      _vars.positionSizeE30ToDecrease,
      _marketConfig.assetClass,
      _vars.position.reserveValueE30,
      _vars.position.entryBorrowingRate,
      _marketConfig.decreasePositionFeeRateBPS
    );

    settleMarginFee(_vars.subAccount);

    // Collect funding fee
    collectFundingFee(
      _vars.subAccount,
      _marketConfig.assetClass,
      _globalMarketIndex,
      _vars.position.positionSizeE30,
      _vars.position.entryFundingRate
    );

    settleFundingFee(_vars.subAccount, _vars.limitPriceE30, _marketConfig.assetId);

    uint256 _newAbsPositionSizeE30 = _vars.absPositionSizeE30 - _vars.positionSizeE30ToDecrease;

    // check position is too tiny
    // @todo - now validate this at 1 USD, design where to keep this config
    //       due to we has problem stack too deep in MarketConfig now
    if (_newAbsPositionSizeE30 > 0 && _newAbsPositionSizeE30 < 1e30) revert ITradeService_TooTinyPosition();

    /**
     * calculate realized profit & loss
     */
    int256 _realizedPnl;
    {
      _vars.avgEntryPriceE30 = _vars.position.avgEntryPriceE30;
      (isProfit, delta) = _getDelta(
        _vars.absPositionSizeE30,
        _vars.isLongPosition,
        _vars.priceE30,
        _vars.avgEntryPriceE30
      );
      // if trader has profit more than our reserved value then trader's profit maximum is reserved value
      if (delta >= _vars.position.reserveValueE30) {
        delta = _vars.position.reserveValueE30;
        _isMaxProfit = true;
      }

      if (isProfit) {
        _realizedPnl = int256((delta * _vars.positionSizeE30ToDecrease) / _vars.absPositionSizeE30);
      } else {
        _realizedPnl = -int256((delta * _vars.positionSizeE30ToDecrease) / _vars.absPositionSizeE30);
      }
    }

    /**
     *  update perp storage
     */
    {
      uint256 _openInterestDelta = (_vars.position.openInterest * _vars.positionSizeE30ToDecrease) /
        _vars.absPositionSizeE30;

      {
        PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_globalMarketIndex);

        if (_vars.isLongPosition) {
          uint256 _nextAvgPrice = _vars.calculator.calculateLongAveragePrice(
            _globalMarket,
            _vars.priceE30,
            -int256(_vars.positionSizeE30ToDecrease),
            _realizedPnl
          );
          _vars.perpStorage.updateGlobalLongMarketById(
            _globalMarketIndex,
            _globalMarket.longPositionSize - _vars.positionSizeE30ToDecrease,
            _nextAvgPrice,
            _globalMarket.longOpenInterest - _openInterestDelta
          );
        } else {
          uint256 _nextAvgPrice = _vars.calculator.calculateShortAveragePrice(
            _globalMarket,
            _vars.priceE30,
            int256(_vars.positionSizeE30ToDecrease),
            _realizedPnl
          );
          _vars.perpStorage.updateGlobalShortMarketById(
            _globalMarketIndex,
            _globalMarket.shortPositionSize - _vars.positionSizeE30ToDecrease,
            _nextAvgPrice,
            _globalMarket.shortOpenInterest - _openInterestDelta
          );
        }

        PerpStorage.GlobalState memory _globalState = _vars.perpStorage.getGlobalState();
        PerpStorage.GlobalAssetClass memory _globalAssetClass = _vars.perpStorage.getGlobalAssetClassByIndex(
          _marketConfig.assetClass
        );

        // update global storage
        // to calculate new global reserve = current global reserve - reserve delta (position reserve * (position size delta / current position size))
        _globalState.reserveValueE30 -=
          (_vars.position.reserveValueE30 * _vars.positionSizeE30ToDecrease) /
          _vars.absPositionSizeE30;
        _globalAssetClass.reserveValueE30 -=
          (_vars.position.reserveValueE30 * _vars.positionSizeE30ToDecrease) /
          _vars.absPositionSizeE30;
        _vars.perpStorage.updateGlobalState(_globalState);
        _vars.perpStorage.updateGlobalAssetClass(_marketConfig.assetClass, _globalAssetClass);

        // update position info
        {
          _vars.position.entryBorrowingRate = _globalAssetClass.sumBorrowingRate;
          _vars.position.entryFundingRate = _globalMarket.currentFundingRate;
          _vars.position.positionSizeE30 = _vars.isLongPosition
            ? int256(_newAbsPositionSizeE30)
            : -int256(_newAbsPositionSizeE30);
          _vars.position.reserveValueE30 =
            ((_newAbsPositionSizeE30 * _marketConfig.initialMarginFractionBPS * _marketConfig.maxProfitRateBPS) / BPS) /
            BPS;
        }
        {
          // @todo - is close position then we should delete positions[x]
          bool isClosePosition = _newAbsPositionSizeE30 == 0;
          _vars.position.avgEntryPriceE30 = isClosePosition ? 0 : _vars.avgEntryPriceE30;
        }

        _vars.position.openInterest = _vars.position.openInterest - _openInterestDelta;
        _vars.position.realizedPnl += _realizedPnl;
        _vars.perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);
      }
    }
    // =======================================
    // | ------ settle profit & loss ------- |
    // =======================================
    {
      if (_realizedPnl != 0) {
        if (_realizedPnl > 0) {
          // profit, trader should receive take profit token = Profit in USD
          _settleProfit(
            _vars.subAccount,
            _vars.tpToken,
            uint256(_realizedPnl),
            _vars.limitPriceE30,
            _marketConfig.assetId
          );
        } else {
          // loss

          _settleLoss(_vars.subAccount, uint256(-_realizedPnl), _vars.limitPriceE30, _marketConfig.assetId);
        }
      }
    }

    // =========================================
    // | --------- post validation ----------- |
    // =========================================

    // check sub account equity is under MMR
    _subAccountHealthCheck(_vars.subAccount, _vars.limitPriceE30, _marketConfig.assetId);

    emit LogDecreasePosition(_vars.positionId, _vars.positionSizeE30ToDecrease);
  }

  /// @notice settle profit
  /// @param _subAccount - Sub-account of trader
  /// @param _tpToken - token that trader want to take profit as collateral
  /// @param _realizedProfitE30 - trader profit in USD
  /// @param _limitPriceE30 - Price to be overwritten to a specified asset
  /// @param _limitAssetId - Asset to be overwritten by _limitPriceE30
  function _settleProfit(
    address _subAccount,
    address _tpToken,
    uint256 _realizedProfitE30,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    uint256 _tpTokenPrice;
    bytes32 _tpAssetId = _configStorage.tokenAssetIds(_tpToken);

    if (_tpAssetId == _limitAssetId && _limitPriceE30 != 0) {
      _tpTokenPrice = _limitPriceE30;
    } else {
      (_tpTokenPrice, ) = OracleMiddleware(_configStorage.oracle()).getLatestPrice(_tpAssetId, false);
    }

    uint256 _decimals = _configStorage.getAssetTokenDecimal(_tpToken);

    // calculate token trader should received
    uint256 _tpTokenOut = (_realizedProfitE30 * (10 ** _decimals)) / _tpTokenPrice;

    uint256 _settlementFeeRate = calculator.getSettlementFeeRate(
      _tpToken,
      _realizedProfitE30,
      _limitPriceE30,
      _limitAssetId
    );
    uint256 _settlementFee = (_tpTokenOut * _settlementFeeRate) / 1e18;

    _vaultStorage.removePLPLiquidity(_tpToken, _tpTokenOut);
    _vaultStorage.addFee(_tpToken, _settlementFee);
    _vaultStorage.increaseTraderBalance(_subAccount, _tpToken, _tpTokenOut - _settlementFee);

    // @todo - emit LogSettleProfit(trader, collateralToken, addedAmount, settlementFee)
  }

  /// @notice settle loss
  /// @param _subAccount - Sub-account of trader
  /// @param _debtUsd - Loss in USD
  /// @param _limitPriceE30 - Price to be overwritten to a specified asset
  /// @param _limitAssetId - Asset to be overwritten by _limitPriceE30
  function _settleLoss(address _subAccount, uint256 _debtUsd, uint256 _limitPriceE30, bytes32 _limitAssetId) internal {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    OracleMiddleware _oracleMiddleware = OracleMiddleware(_configStorage.oracle());
    address[] memory _plpTokens = _configStorage.getPlpTokens();

    uint256 _len = _plpTokens.length;

    SettleLossVars memory _vars;

    // Loop through all the plp tokens for the sub-account
    for (uint256 _i; _i < _len; ) {
      address _token = _plpTokens[_i];

      _vars.decimals = _configStorage.getAssetTokenDecimal(_token);

      // Sub-account plp collateral
      _vars.collateral = _vaultStorage.traderBalances(_subAccount, _token);

      // continue settle when sub-account has collateral, else go to check next token
      if (_vars.collateral != 0) {
        _vars.tokenAssetId = _configStorage.tokenAssetIds(_token);

        // Retrieve the latest price and confident threshold of the plp underlying token
        if (_vars.tokenAssetId == _limitAssetId && _limitPriceE30 != 0) {
          _vars.price = _limitPriceE30;
        } else {
          (_vars.price, ) = _oracleMiddleware.getLatestPrice(_vars.tokenAssetId, false);
        }

        _vars.collateralUsd = (_vars.collateral * _vars.price) / (10 ** _vars.decimals);

        if (_vars.collateralUsd >= _debtUsd) {
          // When this collateral token can cover all the debt, use this token to pay it all
          _vars.collateralToRemove = (_debtUsd * (10 ** _vars.decimals)) / _vars.price;

          _vaultStorage.addPLPLiquidity(_token, _vars.collateralToRemove);
          _vaultStorage.decreaseTraderBalance(_subAccount, _token, _vars.collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // In this case, all debt are paid. We can break the loop right away.
          break;
        } else {
          // When this collateral token cannot cover all the debt, use this token to pay debt as much as possible
          _vars.collateralToRemove = (_vars.collateralUsd * (10 ** _vars.decimals)) / _vars.price;

          _vaultStorage.addPLPLiquidity(_token, _vars.collateralToRemove);
          _vaultStorage.decreaseTraderBalance(_subAccount, _token, _vars.collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // update debtUsd
          unchecked {
            _debtUsd = _debtUsd - _vars.collateralUsd;
          }
        }
        unchecked {
          ++_i;
        }
      }
    }
  }

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice
  ) external pure returns (bool, uint256) {
    return _getDelta(_size, _isLong, _markPrice, _averagePrice);
  }

  // @todo - remove usage from test
  // @todo - move to calculator ??
  // @todo - pass current price here
  /// @notice Calculates the delta between average price and mark price, based on the size of position and whether the position is profitable.
  /// @param _size The size of the position.
  /// @param _isLong position direction
  /// @param _markPrice current market price
  /// @param _averagePrice The average price of the position.
  /// @return isProfit A boolean value indicating whether the position is profitable or not.
  /// @return delta The Profit between the average price and the fixed price, adjusted for the size of the order.
  function _getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice
  ) internal pure returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (_averagePrice == 0) revert ITradeService_InvalidAveragePrice();

    // Calculate the difference between the average price and the fixed price.
    uint256 priceDelta;
    unchecked {
      priceDelta = _averagePrice > _markPrice ? _averagePrice - _markPrice : _markPrice - _averagePrice;
    }

    // Calculate the delta, adjusted for the size of the order.
    uint256 delta = (_size * priceDelta) / _averagePrice;

    // Determine if the position is profitable or not based on the averagePrice and the mark price.
    bool isProfit;
    if (_isLong) {
      isProfit = _markPrice > _averagePrice;
    } else {
      isProfit = _markPrice < _averagePrice;
    }

    // Return the values of isProfit and delta.
    return (isProfit, delta);
  }

  /**
   * Internal functions
   */

  // @todo - add description
  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // @todo - add description
  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  /// @notice Calculates the next average price of a position, given the current position details and the next price.
  /// @param _size The current size of the position.
  /// @param _isLong Whether the position is long or short.
  /// @param _sizeDelta The size difference between the current position and the next position.
  /// @param _markPrice current market price
  /// @param _averagePrice The current average price of the position.
  /// @return The next average price of the position.
  function _getPositionNextAveragePrice(
    uint256 _size,
    bool _isLong,
    uint256 _sizeDelta,
    uint256 _markPrice,
    uint256 _averagePrice
  ) internal pure returns (uint256) {
    // Get the delta and isProfit value from the _getDelta function
    (bool isProfit, uint256 delta) = _getDelta(_size, _isLong, _markPrice, _averagePrice);
    // Calculate the next size and divisor
    uint256 nextSize = _size + _sizeDelta;
    uint256 divisor;
    if (_isLong) {
      divisor = isProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = isProfit ? nextSize - delta : nextSize + delta;
    }

    // Calculate the next average price of the position
    return (_markPrice * nextSize) / divisor;
  }

  /// @notice This function increases the reserve value
  /// @param _assetClassIndex The index of asset class.
  /// @param _reservedValue The amount by which to increase the reserve value.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function _increaseReserved(
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) internal {
    // SLOAD
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the total TVL
    uint256 tvl = calculator.getPLPValueE30(true, _limitPriceE30, _limitAssetId);

    // Retrieve the global state
    PerpStorage.GlobalState memory _globalState = _perpStorage.getGlobalState();

    // Retrieve the global asset class
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);

    // get the liquidity configuration
    ConfigStorage.LiquidityConfig memory _liquidityConfig = ConfigStorage(configStorage).getLiquidityConfig();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += _reservedValue;
    _globalAssetClass.reserveValueE30 += _reservedValue;

    // Check if the new reserve value exceeds the % of AUM, and revert if it does
    if ((tvl * _liquidityConfig.maxPLPUtilizationBPS) < _globalState.reserveValueE30 * BPS) {
      revert ITradeService_InsufficientLiquidity();
    }

    // Update the new reserve value in the PerpStorage contract
    _perpStorage.updateGlobalState(_globalState);
    _perpStorage.updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
  }

  /// @notice health check for sub account that equity > margin maintenance required
  /// @param _subAccount target sub account for health check
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function _subAccountHealthCheck(address _subAccount, uint256 _limitPriceE30, bytes32 _limitAssetId) internal view {
    // check sub account is healthy
    int256 _subAccountEquity = calculator.getEquity(_subAccount, _limitPriceE30, _limitAssetId);
    // maintenance margin requirement (MMR) = position size * maintenance margin fraction
    // note: maintenanceMarginFractionBPS is 1e4
    uint256 _mmr = calculator.getMMR(_subAccount);

    // if sub account equity < MMR, then trader couldn't decrease position
    if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) revert ITradeService_SubAccountEquityIsUnderMMR();
  }

  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function updateBorrowingRate(uint8 _assetClassIndex, uint256 _limitPriceE30, bytes32 _limitAssetId) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.GlobalAssetClass memory _globalAssetClass = _perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);
    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastBorrowingTime = _globalAssetClass.lastBorrowingTime;

    // If last borrowing time is 0, set it to the nearest funding interval time and return.
    if (_lastBorrowingTime == 0) {
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastBorrowingTime + _fundingInterval <= block.timestamp) {
      // update borrowing rate
      uint256 borrowingRate = calculator.getNextBorrowingRate(_assetClassIndex, _limitPriceE30, _limitAssetId);
      _globalAssetClass.sumBorrowingRate += borrowingRate;
      _globalAssetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
    }
    _perpStorage.updateGlobalAssetClass(_assetClassIndex, _globalAssetClass);
  }

  /// @notice This function updates the funding rate for the given market index.
  /// @param _marketIndex The index of the market.
  /// @param _limitPriceE30 Price from limitOrder, zeros means no marketOrderPrice
  function updateFundingRate(uint256 _marketIndex, uint256 _limitPriceE30) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);

    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastFundingTime = _globalMarket.lastFundingTime;

    // If last funding time is 0, set it to the nearest funding interval time and return.
    if (_lastFundingTime == 0) {
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastFundingTime + _fundingInterval <= block.timestamp) {
      // update funding rate
      (int256 newFundingRate, int256 nextFundingFeeLong, int256 nextFundingFeeShort) = calculator.getNextFundingRate(
        _marketIndex,
        _limitPriceE30
      );

      _globalMarket.currentFundingRate = newFundingRate;
      _globalMarket.accumFundingLong += nextFundingFeeLong;
      _globalMarket.accumFundingShort += nextFundingFeeShort;
      _globalMarket.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      _perpStorage.updateGlobalMarket(_marketIndex, _globalMarket);
    }
  }

  /// @notice This function collects margin fee from position
  /// @param _subAccount The sub-account from which to collect the fee.
  /// @param _absSizeDelta Position size to be increased or decreased in absolute value
  /// @param _assetClassIndex The index of the asset class for which to calculate the borrowing fee.
  /// @param _reservedValue The reserved value of the asset class.
  /// @param _entryBorrowingRate The entry borrowing rate of the asset class.
  function collectMarginFee(
    address _subAccount,
    uint256 _absSizeDelta,
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate,
    uint32 _positionFeeBPS
  ) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the debt fee of the sub-account
    int256 feeUsd = _perpStorage.getSubAccountFee(_subAccount);

    // Calculate trading Fee USD
    uint256 tradingFeeUsd = (_absSizeDelta * _positionFeeBPS) / BPS;
    feeUsd += int(tradingFeeUsd);

    emit LogCollectTradingFee(_subAccount, _assetClassIndex, tradingFeeUsd);

    // Calculate the borrowing fee
    uint256 borrowingFee = calculator.getBorrowingFee(_assetClassIndex, _reservedValue, _entryBorrowingRate);
    feeUsd += int(borrowingFee);

    emit LogCollectBorrowingFee(_subAccount, _assetClassIndex, borrowingFee);

    // Update the sub-account's debt fee balance
    _perpStorage.updateSubAccountFee(_subAccount, feeUsd);
  }

  /// @notice This function collects funding fee from position.
  /// @param _subAccount The sub-account from which to collect the fee.
  /// @param _assetClassIndex Index of the asset class associated with the market.
  /// @param _marketIndex Index of the market to collect funding fee from.
  /// @param _positionSizeE30 Size of position in units of 10^-30 of the underlying asset.
  /// @param _entryFundingRate The borrowing rate at the time the position was opened.
  function collectFundingFee(
    address _subAccount,
    uint8 _assetClassIndex,
    uint256 _marketIndex,
    int256 _positionSizeE30,
    int256 _entryFundingRate
  ) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the debt fee of the sub-account
    int256 feeUsd = _perpStorage.getSubAccountFee(_subAccount);

    // Calculate the borrowing fee
    bool isLong = _positionSizeE30 > 0;

    int256 fundingFee = calculator.getFundingFee(_marketIndex, isLong, _positionSizeE30, _entryFundingRate);
    feeUsd += fundingFee;

    emit LogCollectFundingFee(_subAccount, _assetClassIndex, fundingFee);

    // Update the sub-account's debt fee balance
    _perpStorage.updateSubAccountFee(_subAccount, feeUsd);
  }

  /// @notice This function settle margin fee from trader's sub-account
  /// @param _subAccount The sub-account from which to collect the fee.
  function settleMarginFee(address _subAccount) internal {
    FeeCalculator.SettleMarginFeeVar memory acmVars;
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    OracleMiddleware _oracle = OracleMiddleware(_configStorage.oracle());

    // Retrieve the debt fee amount for the sub-account
    acmVars.feeUsd = _perpStorage.getSubAccountFee(_subAccount);

    // If there's no fee that trader need to pay more, return early
    if (acmVars.feeUsd <= 0) return;
    acmVars.absFeeUsd = acmVars.feeUsd > 0 ? uint256(acmVars.feeUsd) : uint256(-acmVars.feeUsd);

    ConfigStorage.TradingConfig memory _tradingConfig = _configStorage.getTradingConfig();
    acmVars.plpUnderlyingTokens = _configStorage.getPlpTokens();

    // Loop through all the plp underlying tokens for the sub-account to pay trading fees
    for (uint256 i = 0; i < acmVars.plpUnderlyingTokens.length; ) {
      FeeCalculator.SettleMarginFeeLoopVar memory tmpVars; // This will be re-assigned every times when start looping
      tmpVars.underlyingToken = acmVars.plpUnderlyingTokens[i];

      tmpVars.underlyingTokenDecimal = _configStorage.getAssetTokenDecimal(tmpVars.underlyingToken);

      tmpVars.traderBalance = _vaultStorage.traderBalances(_subAccount, tmpVars.underlyingToken);

      // If the sub-account has a balance of this underlying token (collateral token amount)
      if (tmpVars.traderBalance > 0) {
        // Retrieve the latest price and confident threshold of the plp underlying token
        (tmpVars.price, ) = _oracle.getLatestPrice(_configStorage.tokenAssetIds(tmpVars.underlyingToken), false);

        tmpVars.feeTokenAmount = (acmVars.absFeeUsd * (10 ** tmpVars.underlyingTokenDecimal)) / tmpVars.price;

        if (tmpVars.traderBalance > tmpVars.feeTokenAmount) {
          tmpVars.repayFeeTokenAmount = tmpVars.feeTokenAmount;
          tmpVars.traderBalance -= tmpVars.feeTokenAmount;
          acmVars.absFeeUsd = 0;
        } else {
          tmpVars.traderBalanceValue = (tmpVars.traderBalance * tmpVars.price) / (10 ** tmpVars.underlyingTokenDecimal);
          tmpVars.repayFeeTokenAmount = tmpVars.traderBalance;
          tmpVars.traderBalance = 0;
          acmVars.absFeeUsd -= tmpVars.traderBalanceValue;
        }

        // Calculate the developer fee amount in the plp underlying token
        tmpVars.devFeeTokenAmount = (tmpVars.repayFeeTokenAmount * _tradingConfig.devFeeRateBPS) / BPS;
        // Deducts for dev fee
        tmpVars.repayFeeTokenAmount -= tmpVars.devFeeTokenAmount;

        {
          // Deduct dev fee from the trading fee and add it to the dev fee pool.
          _vaultStorage.addDevFee(tmpVars.underlyingToken, tmpVars.devFeeTokenAmount);
          // Add the remaining trading fee to the protocol's fee pool.
          _vaultStorage.addFee(tmpVars.underlyingToken, tmpVars.repayFeeTokenAmount);
          // Update the trader's balance of the underlying token.
          _vaultStorage.setTraderBalance(_subAccount, tmpVars.underlyingToken, tmpVars.traderBalance);
        }
      }

      // If no remaining trading fee to pay then stop looping
      if (acmVars.absFeeUsd == 0) break;

      unchecked {
        ++i;
      }
    }

    _perpStorage.updateSubAccountFee(_subAccount, int(acmVars.absFeeUsd));
  }

  /// @notice Settles the fees for a given sub-account.
  /// @param _subAccount The address of the sub-account to settle fees for.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function settleFundingFee(address _subAccount, uint256 _limitPriceE30, bytes32 _limitAssetId) internal {
    FeeCalculator.SettleFundingFeeVar memory acmVars;
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    FeeCalculator _feeCalculator = FeeCalculator(_configStorage.feeCalculator());

    // Retrieve the debt fee amount for the sub-account
    acmVars.feeUsd = _perpStorage.getSubAccountFee(_subAccount);

    // If there's no fee to settle, return early
    if (acmVars.feeUsd == 0) return;

    bool isPayFee = acmVars.feeUsd > 0; // feeUSD > 0 means trader pays fee, feeUSD < 0 means trader gets fee
    acmVars.absFeeUsd = acmVars.feeUsd > 0 ? uint256(acmVars.feeUsd) : uint256(-acmVars.feeUsd);

    OracleMiddleware oracle = OracleMiddleware(_configStorage.oracle());
    acmVars.plpUnderlyingTokens = _configStorage.getPlpTokens();
    acmVars.plpLiquidityDebtUSDE30 = _vaultStorage.plpLiquidityDebtUSDE30(); // Global funding debts that borrowing from PLP

    // Loop through all the plp underlying tokens for the sub-account to receive or pay margin fees
    for (uint256 i = 0; i < acmVars.plpUnderlyingTokens.length; ) {
      FeeCalculator.SettleFundingFeeLoopVar memory tmpVars;
      tmpVars.underlyingToken = acmVars.plpUnderlyingTokens[i];

      tmpVars.underlyingTokenDecimal = _configStorage.getAssetTokenDecimal(tmpVars.underlyingToken);

      // Retrieve the balance of each plp underlying token for the sub-account (token collateral amount)
      tmpVars.traderBalance = _vaultStorage.traderBalances(_subAccount, tmpVars.underlyingToken);

      tmpVars.fundingFee = _vaultStorage.fundingFee(tmpVars.underlyingToken); // Global token amount of funding fee collected from traders

      // Retrieve the latest price and confident threshold of the plp underlying token
      // @todo refactor this?
      bytes32 _underlyingAssetId = _configStorage.tokenAssetIds(tmpVars.underlyingToken);

      // feeUSD > 0 or isPayFee == true, means trader pay fee
      if (isPayFee) {
        // If the sub-account has a balance of this underlying token (collateral token amount)
        if (tmpVars.traderBalance != 0) {
          if (_limitPriceE30 != 0 && _underlyingAssetId == _limitAssetId) {
            tmpVars.price = _limitPriceE30;
          } else {
            (tmpVars.price, ) = oracle.getLatestPrice(_underlyingAssetId, false);
          }

          // If this plp underlying token contains borrowing debt from PLP then trader must repays debt to PLP first
          if (acmVars.plpLiquidityDebtUSDE30 > 0)
            acmVars.absFeeUsd = _feeCalculator.repayFundingFeeDebtToPLP(
              _subAccount,
              acmVars.absFeeUsd,
              acmVars.plpLiquidityDebtUSDE30,
              tmpVars
            );
          // If there are any remaining absFeeUsd, the trader must continue repaying the debt until the full amount is paid off
          if (tmpVars.traderBalance != 0 && acmVars.absFeeUsd > 0) {
            acmVars.absFeeUsd = _feeCalculator.payFundingFee(_subAccount, acmVars.absFeeUsd, tmpVars);
          }
        }
      }
      // feeUSD < 0 or isPayFee == false, means trader receive fee
      else {
        if (tmpVars.fundingFee != 0) {
          if (_limitPriceE30 != 0 && _underlyingAssetId == _limitAssetId) {
            tmpVars.price = _limitPriceE30;
          } else {
            (tmpVars.price, ) = oracle.getLatestPrice(_underlyingAssetId, false);
          }

          acmVars.absFeeUsd = _feeCalculator.receiveFundingFee(_subAccount, acmVars.absFeeUsd, tmpVars);
        }
      }

      // If no remaining margin fee to receive or repay then stop looping
      if (acmVars.absFeeUsd == 0) break;

      {
        unchecked {
          ++i;
        }
      }
    }

    // If a trader is supposed to receive a fee but the amount of tokens received from funding fees is not sufficient to cover the fee,
    // then the protocol must provide the option to borrow in USD and record the resulting debt on the plpLiquidityDebtUSDE30 log
    if (!isPayFee && acmVars.absFeeUsd > 0) {
      acmVars.absFeeUsd = _feeCalculator.borrowFundingFeeFromPLP(
        _subAccount,
        address(oracle),
        acmVars.plpUnderlyingTokens,
        acmVars.absFeeUsd
      );
    }

    // Update the fee amount for the sub-account in the PerpStorage contract
    _perpStorage.updateSubAccountFee(_subAccount, int(acmVars.absFeeUsd));
  }

  /**
   * Maths
   */
  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
