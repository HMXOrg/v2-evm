// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// contracts
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";
import { Owned } from "@hmx/base/Owned.sol";

// interfaces
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";

// @todo - refactor, deduplicate code
contract TradeService is ReentrancyGuard, ITradeService, Owned {
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
    uint256 adaptivePriceE30;
    uint256 priceE30;
    uint256 closePriceE30;
    int32 exponent;
  }
  struct DecreasePositionVars {
    PerpStorage.Position position;
    address subAccount;
    bytes32 positionId;
    uint256 absPositionSizeE30;
    uint256 closePrice;
    bool isLongPosition;
    uint256 positionSizeE30ToDecrease;
    address tpToken;
    uint256 limitPriceE30;
    uint256 oraclePrice;
    int256 realizedPnl;
    int256 unrealizedPnl;
    // for SLOAD
    Calculator calculator;
    PerpStorage perpStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
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
  event LogIncreasePosition(
    bytes32 positionId,
    address primaryAccount,
    uint8 subAccountId,
    address subAccount,
    uint256 marketIndex,
    int256 size,
    int256 increasedSize,
    uint256 avgEntryPrice,
    uint256 entryBorrowingRate,
    int256 entryFundingRate,
    int256 realizedPnl,
    uint256 reserveValueE30
  );

  event LogDecreasePosition(
    bytes32 indexed positionId,
    uint256 marketIndex,
    int256 size,
    int256 decreasedSize,
    uint256 avgEntryPrice,
    uint256 entryBorrowingRate,
    int256 entryFundingRate,
    int256 realizedPnl,
    uint256 reserveValueE30
  );

  event LogForceClosePosition(
    bytes32 indexed positionId,
    address indexed account,
    uint8 subAccountId,
    uint256 marketIndex,
    address tpToken,
    uint256 closedPositionSize,
    bool isProfit,
    uint256 delta
  );

  event LogDeleverage(
    address indexed account,
    uint8 subAccountId,
    uint256 marketIndex,
    address tpToken,
    uint256 closedPositionSize
  );
  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogSetTradeHelper(address indexed oldTradeHelper, address newTradeHelper);

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;
  Calculator public calculator; // cache this from configStorage

  constructor(address _perpStorage, address _vaultStorage, address _configStorage, address _tradeHelper) {
    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    tradeHelper = _tradeHelper;
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
    TradeHelper(tradeHelper).updateBorrowingRate(_marketConfig.assetClass);

    // Update funding rate
    TradeHelper(tradeHelper).updateFundingRate(_marketIndex);

    // get the global market for the given market index
    PerpStorage.GlobalMarket memory _globalMarket = _perpStorage.getGlobalMarketByIndex(_marketIndex);
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      // Get Price market.
      (_vars.adaptivePriceE30, _vars.exponent, _lastPriceUpdated, _marketStatus) = OracleMiddleware(
        _configStorage.oracle()
      ).getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _vars.isLong, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
          _sizeDelta,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      if (_limitPriceE30 != 0) {
        _vars.adaptivePriceE30 = _limitPriceE30;
      }

      (_vars.closePriceE30, , , ) = OracleMiddleware(_configStorage.oracle()).getLatestAdaptivePriceWithMarketStatus(
        _marketConfig.assetId,
        _vars.isLong, // if current position is SHORT position, then we use max price
        (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _marketConfig.fundingRate.maxSkewScaleUSD
      );

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
      _vars.position.avgEntryPriceE30 = _vars.adaptivePriceE30;
      _vars.position.primaryAccount = _primaryAccount;
      _vars.position.subAccountId = _subAccountId;
      _vars.position.marketIndex = _marketIndex;
    }

    // Settle
    // - trading fees
    // - borrowing fees
    // - funding fees
    TradeHelper(tradeHelper).settleAllFees(
      _vars.position,
      _absSizeDelta,
      _marketConfig.increasePositionFeeRateBPS,
      _marketConfig.assetClass,
      _marketIndex
    );

    // update the position size by adding the new size delta
    _vars.position.positionSizeE30 += _sizeDelta;

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (!_vars.isNewPosition) {
      (uint256 _nextClosePriceE30, , , ) = OracleMiddleware(_configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          _vars.isLong, // if current position is SHORT position, then we use max price
          // + new position size delta to update market skew temporary
          (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)) + _sizeDelta,
          // positionSizeE30 is new position size, when updated with sizeDelta above
          -_vars.position.positionSizeE30,
          _marketConfig.fundingRate.maxSkewScaleUSD
        );

      _vars.position.avgEntryPriceE30 = _getPositionNextAveragePrice(
        abs(_vars.position.positionSizeE30),
        _vars.isLong,
        _absSizeDelta,
        _nextClosePriceE30,
        _vars.closePriceE30,
        _vars.position.avgEntryPriceE30,
        _vars.position.lastIncreaseTimestamp
      );
    }

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
        _limitPriceE30,
        _marketConfig.assetId
      );

      // if the free collateral is less than the initial margin required, revert the transaction with an error
      if (subAccountFreeCollateral < _imr) revert ITradeService_InsufficientFreeCollateral();

      // calculate the maximum amount of reserve required for the new position
      uint256 _maxReserve = (_imr * _marketConfig.maxProfitRateBPS) / BPS;
      // increase the reserved amount by the maximum reserve required for the new position
      _increaseReserved(_marketConfig.assetClass, _maxReserve);
      _vars.position.reserveValueE30 += _maxReserve;
    }

    {
      _vars.position.lastIncreaseTimestamp = block.timestamp;

      // update global market state
      if (_vars.isLong) {
        uint256 _nextAvgPrice = _globalMarket.longPositionSize == 0
          ? _vars.adaptivePriceE30
          : _calculator.calculateLongAveragePrice(_globalMarket, _vars.adaptivePriceE30, _sizeDelta, 0);

        _perpStorage.updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize + _absSizeDelta,
          _nextAvgPrice
        );
      } else {
        // to increase SHORT position sizeDelta should be negative
        uint256 _nextAvgPrice = _globalMarket.shortPositionSize == 0
          ? _vars.adaptivePriceE30
          : _calculator.calculateShortAveragePrice(_globalMarket, _vars.adaptivePriceE30, _sizeDelta, 0);

        _perpStorage.updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize + _absSizeDelta,
          _nextAvgPrice
        );
      }
    }

    // save the updated position to the storage
    _perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);

    // Call Trade Service Hook
    _increasePositionHooks(_primaryAccount, _subAccountId, _marketIndex, _absSizeDelta);

    emit LogIncreasePosition(
      _vars.positionId,
      _primaryAccount,
      _subAccountId,
      _vars.subAccount,
      _marketIndex,
      _vars.position.positionSizeE30,
      _sizeDelta,
      _vars.position.avgEntryPriceE30,
      _vars.position.entryBorrowingRate,
      _vars.position.entryFundingRate,
      _vars.position.realizedPnl,
      _vars.position.reserveValueE30
    );
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
    if (_vars.position.positionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.position.positionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.position.positionSizeE30 : -_vars.position.positionSizeE30
    );
    _vars.positionSizeE30ToDecrease = _positionSizeE30ToDecrease;
    _vars.tpToken = _tpToken;
    _vars.limitPriceE30 = _limitPriceE30;
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > _vars.absPositionSizeE30) revert ITradeService_DecreaseTooHighPositionSize();

    PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_marketIndex);
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      (_vars.closePrice, , _lastPriceUpdated, _marketStatus) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _marketConfig.assetId,
        !_vars.isLongPosition, // if current position is SHORT position, then we use max price
        (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _marketConfig.fundingRate.maxSkewScaleUSD
      );

      if (_limitPriceE30 != 0) {
        _vars.closePrice = _limitPriceE30;
      }

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();

      // check sub account equity is under MMR
      _subAccountHealthCheck(_vars.subAccount, _limitPriceE30, _marketConfig.assetId);
    }

    // update position, market, and global market state
    _decreasePosition(_marketConfig, _marketIndex, _vars);

    // Call Trade Service Hook
    _decreasePositionHooks(_account, _subAccountId, _marketIndex, _positionSizeE30ToDecrease);
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
    if (_vars.position.positionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();

    _vars.isLongPosition = _vars.position.positionSizeE30 > 0;

    // convert position size to be uint256
    _vars.absPositionSizeE30 = uint256(
      _vars.isLongPosition ? _vars.position.positionSizeE30 : -_vars.position.positionSizeE30
    );
    _vars.positionSizeE30ToDecrease = _vars.absPositionSizeE30;
    _vars.tpToken = _tpToken;

    PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_marketIndex);

    {
      uint8 _marketStatus;

      (_vars.closePrice, , , _marketStatus) = OracleMiddleware(_vars.configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
          -_vars.position.positionSizeE30,
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
      _vars.positionId,
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
    uint256 _aum = _calculator.getAUME30(false);
    uint256 _tvl = _calculator.getPLPValueE30(false);

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
  /// @return _isMaxProfit - position is close with max profit
  function _decreasePosition(
    ConfigStorage.MarketConfig memory _marketConfig,
    uint256 _globalMarketIndex,
    DecreasePositionVars memory _vars
  ) internal returns (bool _isMaxProfit, bool isProfit, uint256 delta) {
    // Update borrowing rate
    TradeHelper(tradeHelper).updateBorrowingRate(_marketConfig.assetClass);

    // Update funding rate
    TradeHelper(tradeHelper).updateFundingRate(_globalMarketIndex);

    // Settle
    // - trading fees
    // - borrowing fees
    // - funding fees
    TradeHelper(tradeHelper).settleAllFees(
      _vars.position,
      _vars.positionSizeE30ToDecrease,
      _marketConfig.increasePositionFeeRateBPS,
      _marketConfig.assetClass,
      _globalMarketIndex
    );

    uint256 _newAbsPositionSizeE30 = _vars.absPositionSizeE30 - _vars.positionSizeE30ToDecrease;

    // check position is too tiny
    // @todo - now validate this at 1 USD, design where to keep this config
    //       due to we has problem stack too deep in MarketConfig now
    if (_newAbsPositionSizeE30 > 0 && _newAbsPositionSizeE30 < 1e30) revert ITradeService_TooTinyPosition();

    /**
     * calculate realized profit & loss
     */
    {
      (isProfit, delta) = calculator.getDelta(
        _vars.absPositionSizeE30,
        _vars.isLongPosition,
        _vars.closePrice,
        _vars.position.avgEntryPriceE30,
        _vars.position.lastIncreaseTimestamp
      );

      // if trader has profit more than our reserved value then trader's profit maximum is reserved value
      if (isProfit && delta >= _vars.position.reserveValueE30) {
        delta = _vars.position.reserveValueE30;
        _isMaxProfit = true;
      }

      uint256 _toRealizedPnl = (delta * _vars.positionSizeE30ToDecrease) / _vars.absPositionSizeE30;
      if (isProfit) {
        _vars.realizedPnl = int256(_toRealizedPnl);
        _vars.unrealizedPnl = int256(delta - _toRealizedPnl);
      } else {
        _vars.realizedPnl = -int256(_toRealizedPnl);
        _vars.unrealizedPnl = -int256(delta - _toRealizedPnl);
      }
    }

    /**
     *  update perp storage
     */

    {
      PerpStorage.GlobalMarket memory _globalMarket = _vars.perpStorage.getGlobalMarketByIndex(_globalMarketIndex);

      if (_vars.isLongPosition) {
        uint256 _nextAvgPrice = _vars.calculator.calculateLongAveragePrice(
          _globalMarket,
          _vars.closePrice,
          -int256(_vars.positionSizeE30ToDecrease),
          _vars.realizedPnl
        );
        _vars.perpStorage.updateGlobalLongMarketById(
          _globalMarketIndex,
          _globalMarket.longPositionSize - _vars.positionSizeE30ToDecrease,
          _nextAvgPrice
        );
      } else {
        uint256 _nextAvgPrice = _vars.calculator.calculateShortAveragePrice(
          _globalMarket,
          _vars.closePrice,
          int256(_vars.positionSizeE30ToDecrease),
          _vars.realizedPnl
        );
        _vars.perpStorage.updateGlobalShortMarketById(
          _globalMarketIndex,
          _globalMarket.shortPositionSize - _vars.positionSizeE30ToDecrease,
          _nextAvgPrice
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

      if (_newAbsPositionSizeE30 != 0) {
        // @todo - remove this, make this compat with testing that have to set max skew scale
        if (_marketConfig.fundingRate.maxSkewScaleUSD > 0) {
          // calculate new entry price here
          (_vars.oraclePrice, ) = _vars.oracle.getLatestPrice(
            _marketConfig.assetId,
            !_vars.isLongPosition // if current position is SHORT position, then we use max price
          );

          _vars.position.avgEntryPriceE30 = _getNewAvgPriceAfterDecrease(
            (int(_globalMarket.longPositionSize) - int(_globalMarket.shortPositionSize)),
            _vars.position.positionSizeE30,
            _vars.isLongPosition ? int(_vars.positionSizeE30ToDecrease) : -int(_vars.positionSizeE30ToDecrease),
            _vars.unrealizedPnl,
            _vars.oraclePrice,
            _marketConfig.fundingRate.maxSkewScaleUSD
          );
        }

        // update position info
        _vars.position.entryBorrowingRate = _globalAssetClass.sumBorrowingRate;
        _vars.position.entryFundingRate = _globalMarket.currentFundingRate;
        _vars.position.positionSizeE30 = _vars.isLongPosition
          ? int256(_newAbsPositionSizeE30)
          : -int256(_newAbsPositionSizeE30);
        _vars.position.reserveValueE30 =
          ((_newAbsPositionSizeE30 * _marketConfig.initialMarginFractionBPS * _marketConfig.maxProfitRateBPS) / BPS) /
          BPS;
        _vars.position.realizedPnl += _vars.realizedPnl;

        _vars.perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);
      } else {
        _vars.perpStorage.removePositionFromSubAccount(_vars.subAccount, _vars.positionId);
      }
    }

    // =======================================
    // | ------ settle profit & loss ------- |
    // =======================================
    {
      if (_vars.realizedPnl != 0) {
        if (_vars.realizedPnl > 0) {
          // profit, trader should receive take profit token = Profit in USD
          _settleProfit(_vars.subAccount, _vars.tpToken, uint256(_vars.realizedPnl));
        } else {
          // loss
          _settleLoss(_vars.subAccount, uint256(-_vars.realizedPnl));
        }
      }
    }

    // =========================================
    // | --------- post validation ----------- |
    // =========================================

    // check sub account equity is under MMR
    _subAccountHealthCheck(_vars.subAccount, _vars.limitPriceE30, _marketConfig.assetId);

    emit LogDecreasePosition(
      _vars.positionId,
      _globalMarketIndex,
      _vars.position.positionSizeE30,
      int256(_vars.positionSizeE30ToDecrease),
      _vars.position.avgEntryPriceE30,
      _vars.position.entryBorrowingRate,
      _vars.position.entryFundingRate,
      _vars.position.realizedPnl,
      _vars.position.reserveValueE30
    );
  }

  /// @notice settle profit
  /// @param _subAccount - Sub-account of trader
  /// @param _tpToken - token that trader want to take profit as collateral
  /// @param _realizedProfitE30 - trader profit in USD
  function _settleProfit(address _subAccount, address _tpToken, uint256 _realizedProfitE30) internal {
    // SLOAD
    ConfigStorage _configStorage = ConfigStorage(configStorage);
    VaultStorage _vaultStorage = VaultStorage(vaultStorage);

    bytes32 _tpAssetId = _configStorage.tokenAssetIds(_tpToken);
    (uint256 _tpTokenPrice, ) = OracleMiddleware(_configStorage.oracle()).getLatestPrice(_tpAssetId, false);

    uint256 _decimals = _configStorage.getAssetTokenDecimal(_tpToken);

    // calculate token trader should received
    uint256 _tpTokenOut = (_realizedProfitE30 * (10 ** _decimals)) / _tpTokenPrice;

    uint256 _settlementFeeRate = calculator.getSettlementFeeRate(_tpToken, _realizedProfitE30);

    uint256 _settlementFee = (_tpTokenOut * _settlementFeeRate) / 1e18;

    // TODO: no more fee to protocol fee, but discount deduction amount of PLP instead
    _vaultStorage.payTraderProfit(_subAccount, _tpToken, _tpTokenOut, _settlementFee);

    // @todo - emit LogSettleProfit(trader, collateralToken, addedAmount, settlementFee)
  }

  /// @notice settle loss
  /// @param _subAccount - Sub-account of trader
  /// @param _debtUsd - Loss in USD
  function _settleLoss(address _subAccount, uint256 _debtUsd) internal {
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
        (_vars.price, ) = _oracleMiddleware.getLatestPrice(_vars.tokenAssetId, false);

        _vars.collateralUsd = (_vars.collateral * _vars.price) / (10 ** _vars.decimals);

        if (_vars.collateralUsd >= _debtUsd) {
          // When this collateral token can cover all the debt, use this token to pay it all
          _vars.collateralToRemove = (_debtUsd * (10 ** _vars.decimals)) / _vars.price;

          _vaultStorage.payPlp(_subAccount, _token, _vars.collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // In this case, all debt are paid. We can break the loop right away.
          break;
        } else {
          // When this collateral token cannot cover all the debt, use this token to pay debt as much as possible
          _vars.collateralToRemove = (_vars.collateralUsd * (10 ** _vars.decimals)) / _vars.price;

          _vaultStorage.payPlp(_subAccount, _token, _vars.collateralToRemove);
          // @todo - emit LogSettleLoss(trader, collateralToken, deductedAmount)
          // update debtUsd
          unchecked {
            _debtUsd = _debtUsd - _vars.collateralUsd;
          }
        }
      }

      unchecked {
        ++_i;
      }
    }
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
  /// @param _closePrice the adaptive price of this market if this position is fully closed. This is used to correctly calculate position pnl.
  /// @param _averagePrice The current average price of the position.
  /// @return The next average price of the position.
  function _getPositionNextAveragePrice(
    uint256 _size,
    bool _isLong,
    uint256 _sizeDelta,
    uint256 _markPrice,
    uint256 _closePrice,
    uint256 _averagePrice,
    uint256 _lastIncreaseTimestamp
  ) internal view returns (uint256) {
    // Get the delta and isProfit value from the _getDelta function
    (bool isProfit, uint256 delta) = calculator.getDelta(
      _size,
      _isLong,
      _closePrice,
      _averagePrice,
      _lastIncreaseTimestamp
    );

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

  /// @notice Calculates the next average price of a position, after decrease position
  /// @param _marketSkew market skew of market before decrease
  /// @param _positionSize position size. positive number for Long position and negative for Short
  /// @param _sizeToDecrease size to decrease. positive number for Long position and negative for Short
  /// @param _unrealizedPnl delta - realized pnl
  /// @param _priceE30 oracle price
  /// @param _maxSkewScale - max skew scale
  /// @return _newAveragePrice
  function _getNewAvgPriceAfterDecrease(
    int256 _marketSkew,
    int256 _positionSize,
    int256 _sizeToDecrease,
    int256 _unrealizedPnl,
    uint256 _priceE30,
    uint256 _maxSkewScale
  ) internal pure returns (uint256 _newAveragePrice) {
    // premium before       = market skew - size delta / max scale skew
    // premium after        = market skew - position size / max scale skew
    // premium              = (premium after + premium after) / 2
    // new close price      = 100 * (1 + premium)
    // remaining size       = position size - size delta
    // new avg price        = (new close price * remaining size) / (remaining size + unrealized pnl)

    // Example:
    // Given
    //    - max scale       = 1000000 USD
    //    - market skew     = 2000 USD
    //    - price           = 100 USD
    //    - position size   = 1000 USD
    //    - decrease size   = 300 USD
    //    - remaining size  = 500 USD
    //    - entry price     = 100.05 USD
    //    - close price     = 100.15 USD
    //    - pnl             = 1000 * (100.15 - 100.05) / 100.05 = 0.999500249875062468765617191404 USD
    //    - reliazed pnl    = 300 * (100.15 - 100.05) / 100.05 = 0.299850074962518740629685157421 USD
    //    - unrealized pnl  = 0.999500249875062468765617191404 - 0.299850074962518740629685157421
    //                      = 0.699650174912543728135932033983
    // Then
    //    - premium before      = 2000 - 300 = 1700 / 1000000 = 0.0017
    //    - premium after       = 2000 - 1000 = 1000 / 1000000 = 0.001
    //    - new premium         = 0.0017 + 0.001 = 0.0027 / 2 = 0.00135
    //    - price with premium  = 100 * (1 + 0.00135) = 100.135 USD
    //    - new avg price       = (100.135 * 700) / (700 + 0.699650174912543728135932033983)
    //                          = 100.035014977533699450823764353469 USD

    int256 _premiumBefore = ((_marketSkew - _sizeToDecrease) * 1e30) / int256(_maxSkewScale);
    int256 _premiumAfter = ((_marketSkew - _positionSize) * 1e30) / int256(_maxSkewScale);

    int256 _premium = (_premiumBefore + _premiumAfter) / 2;

    uint256 _priceWithPremium;
    if (_premium > 0) {
      _priceWithPremium = (_priceE30 * (1e30 + uint256(_premium))) / 1e30;
    } else {
      _priceWithPremium = (_priceE30 * (1e30 - uint256(-_premium))) / 1e30;
    }

    int256 _remainingSize = _positionSize - _sizeToDecrease;
    return uint256((int256(_priceWithPremium) * _remainingSize) / (_remainingSize + _unrealizedPnl));
  }

  /// @notice This function increases the reserve value
  /// @param _assetClassIndex The index of asset class.
  /// @param _reservedValue The amount by which to increase the reserve value.
  function _increaseReserved(uint8 _assetClassIndex, uint256 _reservedValue) internal {
    // SLOAD
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the total TVL
    uint256 tvl = calculator.getPLPValueE30(true);

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

  function _increasePositionHooks(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) internal {
    address[] memory _hooks = ConfigStorage(configStorage).getTradeServiceHooks();
    for (uint256 i; i < _hooks.length; ) {
      ITradeServiceHook(_hooks[i]).onIncreasePosition(_primaryAccount, _subAccountId, _marketIndex, _sizeDelta, "");
      unchecked {
        ++i;
      }
    }
  }

  function _decreasePositionHooks(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) internal {
    address[] memory _hooks = ConfigStorage(configStorage).getTradeServiceHooks();
    for (uint256 i; i < _hooks.length; ) {
      ITradeServiceHook(_hooks[i]).onDecreasePosition(_primaryAccount, _subAccountId, _marketIndex, _sizeDelta, "");
      unchecked {
        ++i;
      }
    }
  }

  /**
   * Maths
   */
  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ITradeService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ITradeService_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ITradeService_InvalidAddress();

    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external nonReentrant onlyOwner {
    if (_calculator == address(0)) revert ITradeService_InvalidAddress();

    emit LogSetCalculator(address(calculator), _calculator);
    calculator = Calculator(_calculator);

    // Sanity check
    Calculator(_calculator).oracle();
  }

  /// @notice Set new TradeHelper contract address.
  /// @param _tradeHelper New TradeHelper contract address.
  function setTradeHelper(address _tradeHelper) external nonReentrant onlyOwner {
    if (_tradeHelper == address(0)) revert ITradeService_InvalidAddress();

    emit LogSetTradeHelper(tradeHelper, _tradeHelper);
    tradeHelper = _tradeHelper;

    // Sanity check
    TradeHelper(_tradeHelper).perpStorage();
  }
}
