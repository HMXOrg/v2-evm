// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// bases
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";

// contracts
import { FullMath } from "@hmx/libraries/FullMath.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";

// interfaces
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";

contract TradeService is ReentrancyGuardUpgradeable, ITradeService, OwnableUpgradeable {
  using FullMath for uint256;
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;

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
   * Structs
   */
  struct IncreasePositionVars {
    bytes32 positionId;
    uint256 adaptivePriceE30;
    uint256 oraclePrice;
    uint256 closePriceE30;
    uint256 nextClosePrice;
    uint256 absSizeDelta;
    int256 unrealizedPnl;
    address subAccount;
    bool isLong;
    bool isNewPosition;
    bool currentPositionIsLong;
    uint256 oldSumSe;
    uint256 oldSumS2e;
    // for SLOAD
    PerpStorage.Position position;
    OracleMiddleware oracle;
    ConfigStorage configStorage;
    Calculator calculator;
    PerpStorage perpStorage;
    TradeHelper tradeHelper;
  }

  struct DecreasePositionVars {
    uint256 absPositionSizeE30;
    uint256 positionSizeE30ToDecrease;
    uint256 closePrice;
    uint256 limitPriceE30;
    uint256 oraclePrice;
    uint256 tradingFee;
    uint256 borrowingFee;
    int256 realizedPnl;
    int256 unrealizedPnl;
    int256 fundingFee;
    bool isLongPosition;
    address subAccount;
    address tpToken;
    bytes32 positionId;
    uint256 nextClosePrice;
    uint256 oldSumSe;
    uint256 oldSumS2e;
    uint256 nextAvgPrice;
    // for SLOAD
    Calculator calculator;
    PerpStorage perpStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    PerpStorage.Position position;
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
   * Constants
   */
  uint32 private constant BPS = 1e4;
  uint64 private constant RATE_PRECISION = 1e18;

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;
  Calculator public calculator; // cache this from configStorage

  /// @notice Initializes the contract and sets the required contract addresses.
  /// @param _perpStorage Address of the PerpStorage contract.
  /// @param _vaultStorage Address of the VaultStorage contract.
  /// @param _configStorage Address of the ConfigStorage contract.
  /// @param _tradeHelper Address of the TradeHelper contract.
  function initialize(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

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

  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /**
   * Core Functions
   */
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
    IncreasePositionVars memory _vars;
    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = calculator;
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    // get the sub-account from the primary account and sub-account ID
    _vars.subAccount = _getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);

    // get the global market for the given market index
    PerpStorage.Market memory _market = _vars.perpStorage.getMarketByIndex(_marketIndex);
    // get the market configuration for the given market index
    ConfigStorage.MarketConfig memory _marketConfig = _vars.configStorage.getMarketConfigByIndex(_marketIndex);

    {
      // check size delta
      if (_sizeDelta == 0) revert ITradeService_BadSizeDelta();

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // check allow increase position
      if (!_marketConfig.allowIncreasePosition) revert ITradeService_NotAllowIncrease();

      // check sub account equity is under MMR
      _subAccountHealthCheck(_vars.subAccount, _limitPriceE30, _marketConfig.assetId);
    }

    // determine whether the new size delta is for a long position
    _vars.isLong = _sizeDelta > 0;
    if (
      _vars.isLong
        ? _market.longPositionSize + uint256(_sizeDelta) > _marketConfig.maxLongPositionSize
        : _market.shortPositionSize + uint256(-_sizeDelta) > _marketConfig.maxShortPositionSize
    ) revert ITradeService_PositionSizeExceed();

    _vars.isNewPosition = _vars.position.positionSizeE30 == 0;

    // Pre validation
    // Verify that the number of positions has exceeds
    {
      if (
        _vars.isNewPosition &&
        _vars.configStorage.getTradingConfig().maxPosition <
        _vars.perpStorage.getNumberOfSubAccountPosition(_vars.subAccount) + 1
      ) revert ITradeService_BadNumberOfPosition();
    }

    _vars.currentPositionIsLong = _vars.position.positionSizeE30 > 0;
    // Verify that the current position has the same exposure direction
    if (!_vars.isNewPosition && _vars.currentPositionIsLong != _vars.isLong) revert ITradeService_BadExposure();

    {
      // Update borrowing rate
      _vars.tradeHelper.updateBorrowingRate(_marketConfig.assetClass);

      // Update funding rate
      _vars.tradeHelper.updateFundingRate(_marketIndex);
    }

    // update global market state after update fee rate
    _market = _vars.perpStorage.getMarketByIndex(_marketIndex);

    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      // Get Price market.
      (_vars.oraclePrice, ) = _vars.oracle.getLatestPrice(
        _marketConfig.assetId,
        !_vars.isLong // if current position is SHORT position, then we use max price
      );

      (_vars.adaptivePriceE30, _lastPriceUpdated, _marketStatus) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _marketConfig.assetId,
        _vars.isLong, // if current position is SHORT position, then we use max price
        (int(_market.longPositionSize) - int(_market.shortPositionSize)),
        _sizeDelta,
        _marketConfig.fundingRate.maxSkewScaleUSD,
        _limitPriceE30
      );

      (_vars.closePriceE30, , ) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _marketConfig.assetId,
        _vars.isLong, // if current position is SHORT position, then we use max price
        (int(_market.longPositionSize) - int(_market.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _marketConfig.fundingRate.maxSkewScaleUSD,
        0
      );

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketStatus != 2) revert ITradeService_MarketIsClosed();
    }

    // get the absolute value of the new size delta
    _vars.absSizeDelta = _abs(_sizeDelta);
    _vars.oldSumSe = 0;
    _vars.oldSumS2e = 0;

    // if new position, set the average price to the current price
    if (_vars.isNewPosition) {
      _vars.position.avgEntryPriceE30 = _vars.adaptivePriceE30;
      _vars.position.primaryAccount = _primaryAccount;
      _vars.position.subAccountId = _subAccountId;
      _vars.position.marketIndex = _marketIndex;
    }

    {
      // Settle all fees
      // - trading fees
      // - borrowing fees
      // - funding fees
      _vars.tradeHelper.settleAllFees(
        _vars.positionId,
        _vars.position,
        _vars.absSizeDelta,
        _marketConfig.increasePositionFeeRateBPS,
        _marketConfig.assetClass
      );
    }

    _vars.nextClosePrice = _calculateNextClosePrice(
      _market,
      _marketConfig.fundingRate.maxSkewScaleUSD,
      _vars.oraclePrice,
      _vars.position.positionSizeE30,
      _sizeDelta
    );

    // if adjust position, calculate the new average price
    if (!_vars.isNewPosition) {
      (bool _isProfit, uint256 _delta) = calculator.getDelta(
        _abs(_vars.position.positionSizeE30),
        _vars.isLong,
        _vars.closePriceE30,
        _vars.position.avgEntryPriceE30,
        _vars.position.lastIncreaseTimestamp
      );

      int256 deltaPnl = _vars.isLong ? int256(_delta) : -int256(_delta);
      _vars.unrealizedPnl = _isProfit ? deltaPnl : -deltaPnl;

      uint256 absPositionSizeE30 = _abs(_vars.position.positionSizeE30);
      _vars.oldSumSe = absPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30);
      _vars.oldSumS2e = absPositionSizeE30.mulDiv(absPositionSizeE30, _vars.position.avgEntryPriceE30);

      _vars.position.avgEntryPriceE30 = _calculateEntryAveragePrice(
        _vars.position.positionSizeE30,
        _sizeDelta,
        _vars.nextClosePrice,
        _vars.unrealizedPnl
      );
    }

    // update the position size by adding the new size delta
    _vars.position.positionSizeE30 += _sizeDelta;
    _vars.position.lastIncreaseTimestamp = block.timestamp;

    // if the position size is zero after the update, revert the transaction with an error
    if (_vars.position.positionSizeE30 == 0) revert ITradeService_BadPositionSize();
    // Ensure that the new absolute position size is greater than zero, but not smaller than the minimum allowed position size
    if (
      _abs(_vars.position.positionSizeE30) > 0 &&
      _abs(_vars.position.positionSizeE30) < ConfigStorage(configStorage).minimumPositionSize()
    ) revert ITradeService_TooTinyPosition();

    // update entry borrowing/funding rates
    {
      PerpStorage.AssetClass memory _assetClass = _vars.perpStorage.getAssetClassByIndex(_marketConfig.assetClass);
      _vars.position.entryBorrowingRate = _assetClass.sumBorrowingRate;
      _vars.position.entryFundingRate = _market.currentFundingRate;
    }

    {
      // calculate the initial margin required for the new position
      uint256 _imr = (_vars.absSizeDelta * _marketConfig.initialMarginFractionBPS) / BPS;

      // calculate the maximum amount of reserve required for the new position
      uint256 _maxReserve = (_imr * _marketConfig.maxProfitRateBPS) / BPS;
      // increase the reserved amount by the maximum reserve required for the new position
      _increaseReserved(_marketConfig.assetClass, _maxReserve);
      _vars.position.reserveValueE30 += _maxReserve;
    }

    // update counter trade states
    {
      if (_vars.isNewPosition) {
        _vars.isLong
          ? _vars.perpStorage.updateGlobalLongMarketById(
            _marketIndex,
            _market.longPositionSize + _vars.absSizeDelta,
            _market.longAccumSE + _vars.absSizeDelta.mulDiv(1e30, _vars.position.avgEntryPriceE30),
            _market.longAccumS2E + _vars.absSizeDelta.mulDiv(_vars.absSizeDelta, _vars.position.avgEntryPriceE30)
          )
          : _vars.perpStorage.updateGlobalShortMarketById(
            _marketIndex,
            _market.shortPositionSize + _vars.absSizeDelta,
            _market.shortAccumSE + ((_vars.absSizeDelta * 1e30) / _vars.position.avgEntryPriceE30),
            _market.shortAccumS2E + _vars.absSizeDelta.mulDiv(_vars.absSizeDelta, _vars.position.avgEntryPriceE30)
          );
      } else {
        uint256 absNewPositionSizeE30 = _abs(_vars.position.positionSizeE30);
        _vars.isLong
          ? _vars.perpStorage.updateGlobalLongMarketById(
            _marketIndex,
            _market.longPositionSize + _vars.absSizeDelta,
            (_market.longAccumSE - _vars.oldSumSe) +
              absNewPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30),
            (_market.longAccumS2E - _vars.oldSumS2e) +
              absNewPositionSizeE30.mulDiv(absNewPositionSizeE30, _vars.position.avgEntryPriceE30)
          )
          : _vars.perpStorage.updateGlobalShortMarketById(
            _marketIndex,
            _market.shortPositionSize + _vars.absSizeDelta,
            (_market.shortAccumSE - _vars.oldSumSe) +
              absNewPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30),
            (_market.shortAccumS2E - _vars.oldSumS2e) +
              absNewPositionSizeE30.mulDiv(absNewPositionSizeE30, _vars.position.avgEntryPriceE30)
          );
      }
    }

    // save the updated position to the storage
    _vars.perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);

    {
      // get the amount of free collateral available for the sub-account
      int256 subAccountFreeCollateral = _vars.calculator.getFreeCollateral(
        _vars.subAccount,
        _limitPriceE30,
        _marketConfig.assetId
      );

      // if the free collateral is less than zero, revert the transaction with an error
      if (subAccountFreeCollateral < 0) revert ITradeService_InsufficientFreeCollateral();
    }

    // Call Trade Service Hook
    _increasePositionHooks(_primaryAccount, _subAccountId, _marketIndex, _vars.absSizeDelta);

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

  /// @notice Decreases a trader's position in a given market.
  /// @param _account The trader's address.
  /// @param _subAccountId The sub-account ID.
  /// @param _marketIndex The index of the market.
  /// @param _positionSizeE30ToDecrease The amount to decrease the position size by, in units of 10^-30 of the base asset.
  /// @param _tpToken The take profit token address.
  /// @param _limitPriceE30 The limit price in units of 10^-30 of the quote asset.
  function decreasePosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease,
    address _tpToken,
    uint256 _limitPriceE30
  ) external nonReentrant onlyWhitelistedExecutor {
    DecreasePositionVars memory _vars;
    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.calculator = calculator;
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    ConfigStorage.MarketConfig memory _marketConfig = _vars.configStorage.getMarketConfigByIndex(_marketIndex);

    // validates
    {
      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();
    }

    // prepare variables
    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);
    _vars.isLongPosition = _vars.position.positionSizeE30 > 0;
    _vars.absPositionSizeE30 = uint256(_abs(_vars.position.positionSizeE30));
    _vars.positionSizeE30ToDecrease = _positionSizeE30ToDecrease;
    _vars.tpToken = _tpToken;
    _vars.limitPriceE30 = _limitPriceE30;

    // if position size is 0 means this position is already closed
    if (_vars.position.positionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();
    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > _vars.absPositionSizeE30) revert ITradeService_DecreaseTooHighPositionSize();

    PerpStorage.Market memory _market = _vars.perpStorage.getMarketByIndex(_marketIndex);
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      (_vars.closePrice, _lastPriceUpdated, _marketStatus) = _vars.oracle.getLatestAdaptivePriceWithMarketStatus(
        _marketConfig.assetId,
        !_vars.isLongPosition, // if current position is SHORT position, then we use max price
        (int(_market.longPositionSize) - int(_market.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _marketConfig.fundingRate.maxSkewScaleUSD,
        _limitPriceE30
      );

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
    DecreasePositionVars memory _vars;
    // SLOAD
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = calculator;
    _vars.perpStorage = PerpStorage(perpStorage);

    // prepare variables
    ConfigStorage.MarketConfig memory _marketConfig = _vars.configStorage.getMarketConfigByIndex(_marketIndex);
    _vars.subAccount = _getSubAccount(_account, _subAccountId);
    _vars.positionId = _getPositionId(_vars.subAccount, _marketIndex);
    _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    {
      // if position size is 0 means this position is already closed
      if (_vars.position.positionSizeE30 == 0) revert ITradeService_PositionAlreadyClosed();
    }

    _vars.isLongPosition = _vars.position.positionSizeE30 > 0;
    _vars.absPositionSizeE30 = uint256(_abs(_vars.position.positionSizeE30));
    _vars.positionSizeE30ToDecrease = _vars.absPositionSizeE30;
    _vars.tpToken = _tpToken;

    PerpStorage.Market memory _market = _vars.perpStorage.getMarketByIndex(_marketIndex);
    {
      uint8 _marketStatus;

      (_vars.closePrice, , _marketStatus) = OracleMiddleware(_vars.configStorage.oracle())
        .getLatestAdaptivePriceWithMarketStatus(
          _marketConfig.assetId,
          !_vars.isLongPosition, // if current position is SHORT position, then we use max price
          (int(_market.longPositionSize) - int(_market.shortPositionSize)),
          -_vars.position.positionSizeE30,
          _marketConfig.fundingRate.maxSkewScaleUSD,
          0
        );

      // if market status is not 2, means that the market is closed or market status has been defined yet
      if (_marketConfig.active && _marketStatus != 2) revert ITradeService_MarketIsClosed();
      // check sub account equity is under MMR
      /// @dev no need to derived price on this
      _subAccountHealthCheck(_vars.subAccount, 0, 0);
    }

    // update position, market, and global market state
    (_isMaxProfit, _isProfit, _delta) = _decreasePosition(_marketConfig, _marketIndex, _vars);

    // Call Trade Service Hook
    _decreasePositionHooks(_account, _subAccountId, _marketIndex, _vars.positionSizeE30ToDecrease);

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

  /// @notice Reloads the configuration for the contract.
  function reloadConfig() external nonReentrant onlyOwner {
    calculator = Calculator(ConfigStorage(configStorage).calculator());
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

  /**
   * Private Functions
   */

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) private pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function _getPositionId(address _account, uint256 _marketIndex) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  struct PrivateDecreasePositionVars {
    uint256 newAbsPositionSizeE30;
    TradeHelper tradeHelper;
  }

  /// @notice Decreases a trader's position in a market.
  /// @param _marketConfig The market configuration.
  /// @param _marketIndex The index of the market to decrease the position in.
  /// @param _vars The `DecreasePositionVars` struct containing variables related to the position to be decreased.
  /// @return _isMaxProfit Whether the maximum profit has been reached.
  /// @return isProfit Whether the position decrease is profitable.
  /// @return delta The profit/loss delta.
  function _decreasePosition(
    ConfigStorage.MarketConfig memory _marketConfig,
    uint256 _marketIndex,
    DecreasePositionVars memory _vars
  ) private returns (bool _isMaxProfit, bool isProfit, uint256 delta) {
    PrivateDecreasePositionVars memory _temp;
    // SLOAD
    _temp.tradeHelper = TradeHelper(tradeHelper);

    {
      // Update borrowing rate
      _temp.tradeHelper.updateBorrowingRate(_marketConfig.assetClass);

      // Update funding rate
      _temp.tradeHelper.updateFundingRate(_marketIndex);

      (_vars.tradingFee, _vars.borrowingFee, _vars.fundingFee) = _temp.tradeHelper.updateFeeStates(
        _vars.positionId,
        _vars.subAccount,
        _vars.position,
        _vars.positionSizeE30ToDecrease,
        _marketConfig.increasePositionFeeRateBPS,
        _marketConfig.assetClass,
        _marketIndex
      );
    }
    _vars.oldSumSe = _vars.absPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30);
    _vars.oldSumS2e = _vars.absPositionSizeE30.mulDiv(_vars.absPositionSizeE30, _vars.position.avgEntryPriceE30);

    _temp.newAbsPositionSizeE30 = _vars.absPositionSizeE30 - _vars.positionSizeE30ToDecrease;

    // Ensure that the new absolute position size is greater than zero, but not smaller than the minimum allowed position size
    if (
      _temp.newAbsPositionSizeE30 > 0 &&
      _temp.newAbsPositionSizeE30 < ConfigStorage(configStorage).minimumPositionSize()
    ) revert ITradeService_TooTinyPosition();

    PerpStorage.Market memory _market = _vars.perpStorage.getMarketByIndex(_marketIndex);

    {
      // calculate next close price
      (_vars.oraclePrice, ) = _vars.oracle.getLatestPrice(
        _marketConfig.assetId,
        !_vars.isLongPosition // if current position is SHORT position, then we use max price
      );

      _vars.nextClosePrice = _calculateNextClosePrice(
        _market,
        _marketConfig.fundingRate.maxSkewScaleUSD,
        _vars.oraclePrice,
        _vars.position.positionSizeE30,
        _vars.isLongPosition ? -int(_vars.positionSizeE30ToDecrease) : int(_vars.positionSizeE30ToDecrease)
      );
    }

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
      // update global & asset class state
      PerpStorage.GlobalState memory _globalState = _vars.perpStorage.getGlobalState();
      PerpStorage.AssetClass memory _assetClass = _vars.perpStorage.getAssetClassByIndex(_marketConfig.assetClass);

      // update global storage
      // to calculate new global reserve = current global reserve - reserve delta (position reserve * (position size delta / current position size))
      _globalState.reserveValueE30 -=
        (_vars.position.reserveValueE30 * _vars.positionSizeE30ToDecrease) /
        _vars.absPositionSizeE30;
      _assetClass.reserveValueE30 -=
        (_vars.position.reserveValueE30 * _vars.positionSizeE30ToDecrease) /
        _vars.absPositionSizeE30;
      _vars.perpStorage.updateGlobalState(_globalState);
      _vars.perpStorage.updateAssetClass(_marketConfig.assetClass, _assetClass);

      // partial close position
      if (_temp.newAbsPositionSizeE30 != 0) {
        _vars.position.avgEntryPriceE30 = _calculateEntryAveragePrice(
          _vars.position.positionSizeE30,
          _vars.isLongPosition ? -int(_vars.positionSizeE30ToDecrease) : int(_vars.positionSizeE30ToDecrease),
          _vars.nextClosePrice,
          _vars.isLongPosition ? _vars.unrealizedPnl : -_vars.unrealizedPnl
        );

        // update position info
        _vars.position.entryBorrowingRate = _assetClass.sumBorrowingRate;
        _vars.position.entryFundingRate = _market.currentFundingRate;
        _vars.position.positionSizeE30 = _vars.isLongPosition
          ? int256(_temp.newAbsPositionSizeE30)
          : -int256(_temp.newAbsPositionSizeE30);
        _vars.position.reserveValueE30 =
          ((_temp.newAbsPositionSizeE30 * _marketConfig.initialMarginFractionBPS * _marketConfig.maxProfitRateBPS) /
            BPS) /
          BPS;
        _vars.position.realizedPnl += _vars.realizedPnl;

        _vars.perpStorage.savePosition(_vars.subAccount, _vars.positionId, _vars.position);
      } else {
        _vars.perpStorage.removePositionFromSubAccount(_vars.subAccount, _vars.positionId);
      }

      // update counter trade states
      {
        _vars.isLongPosition
          ? _vars.perpStorage.updateGlobalLongMarketById(
            _marketIndex,
            _market.longPositionSize - _vars.positionSizeE30ToDecrease,
            _vars.position.avgEntryPriceE30 > 0
              ? (_market.longAccumSE - _vars.oldSumSe) +
                _temp.newAbsPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30)
              : 0,
            _vars.position.avgEntryPriceE30 > 0
              ? (_market.longAccumS2E - _vars.oldSumS2e) +
                _temp.newAbsPositionSizeE30.mulDiv(_temp.newAbsPositionSizeE30, _vars.position.avgEntryPriceE30)
              : 0
          )
          : _vars.perpStorage.updateGlobalShortMarketById(
            _marketIndex,
            _market.shortPositionSize - _vars.positionSizeE30ToDecrease,
            _vars.position.avgEntryPriceE30 > 0
              ? (_market.shortAccumSE - _vars.oldSumSe) +
                _temp.newAbsPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30)
              : 0,
            _vars.position.avgEntryPriceE30 > 0
              ? (_market.shortAccumS2E - _vars.oldSumS2e) +
                _temp.newAbsPositionSizeE30.mulDiv(_temp.newAbsPositionSizeE30, _vars.position.avgEntryPriceE30)
              : 0
          );
      }
    }

    // =======================================
    // | ------ settle profit & loss ------- |
    // =======================================
    _temp.tradeHelper.increaseCollateral(
      _vars.positionId,
      _vars.subAccount,
      _vars.realizedPnl,
      _vars.fundingFee,
      _vars.tpToken
    );
    _temp.tradeHelper.decreaseCollateral(
      _vars.positionId,
      _vars.subAccount,
      _vars.realizedPnl,
      _vars.fundingFee,
      _vars.borrowingFee,
      _vars.tradingFee,
      0,
      address(0)
    );

    // =========================================
    // | --------- post validation ----------- |
    // =========================================

    // check sub account equity is under MMR
    _subAccountHealthCheck(_vars.subAccount, _vars.limitPriceE30, _marketConfig.assetId);

    emit LogDecreasePosition(
      _vars.positionId,
      _marketIndex,
      _vars.position.positionSizeE30,
      int256(_vars.positionSizeE30ToDecrease),
      _vars.position.avgEntryPriceE30,
      _vars.position.entryBorrowingRate,
      _vars.position.entryFundingRate,
      _vars.position.realizedPnl,
      _vars.position.reserveValueE30
    );
  }

  /// @notice Calculates new entry average price
  /// @param _positionSize - position's size before updated (long +, short -)
  /// @param _sizeDelta - position's size to increase or decrease
  ///                   - increase => long +, short -
  ///                   - decrease => long -, short +
  /// @param _nextClosePrice - close price after position has been updated
  /// @param _unrealizedPnl - unrealized profit and loss
  ///                   - long position => profit +, loss -
  ///                   - short position => profit -, loss +
  function _calculateEntryAveragePrice(
    int256 _positionSize,
    int256 _sizeDelta,
    uint256 _nextClosePrice,
    int256 _unrealizedPnl
  ) private pure returns (uint256 _newEntryAveragePrice) {
    int256 _newPositionSize = _positionSize + _sizeDelta;

    if (_positionSize > 0) {
      return uint256((int256(_nextClosePrice) * _newPositionSize) / (_newPositionSize + _unrealizedPnl));
    } else {
      return uint256((int256(_nextClosePrice) * _newPositionSize) / (_newPositionSize - _unrealizedPnl));
    }
  }

  /// @notice Calculates new close price after position has been updated
  /// @param _market - buy / sell market's state before updated
  /// @param _maxSkewScale - max market skew scale from market config
  /// @param _oraclePrice - price from oracle
  /// @param _positionSize - position's size before updated (long +, short -)
  /// @param _sizeDelta - position's size to increase or decrease
  ///                   - increase => long +, short -
  ///                   - decrease => long -, short +
  function _calculateNextClosePrice(
    PerpStorage.Market memory _market,
    uint256 _maxSkewScale,
    uint256 _oraclePrice,
    int256 _positionSize,
    int256 _sizeDelta
  ) private pure returns (uint256 _nextClosePrice) {
    if (_maxSkewScale == 0) return _oraclePrice;

    // premium before       = market skew - size delta / max scale skew
    // premium after        = market skew - position size / max scale skew
    // premium              = (premium after + premium after) / 2
    // next close price     = 100 * (1 + premium)
    // remaining size       = position size - size delta
    // next avg price       = (next close price * remaining size) / (remaining size + unrealized pnl)

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
    //    - realized pnl    = 300 * (100.15 - 100.05) / 100.05 = 0.299850074962518740629685157421 USD
    //    - unrealized pnl  = 0.999500249875062468765617191404 - 0.299850074962518740629685157421
    //                      = 0.699650174912543728135932033983
    // Then
    //    - premium before      = 2000 - 300 = 1700 / 1000000 = 0.0017
    //    - premium after       = 2000 - 1000 = 1000 / 1000000 = 0.001
    //    - new premium         = 0.0017 + 0.001 = 0.0027 / 2 = 0.00135
    //    - next close price    = 100 * (1 + 0.00135) = 100.135 USD

    int256 _newPositionSize = _positionSize + _sizeDelta;

    int256 _newMarketSkew = int256(_market.longPositionSize) - int256(_market.shortPositionSize) + _sizeDelta;

    int256 _premiumBefore = (_newMarketSkew * 1e30) / int256(_maxSkewScale);
    int256 _premiumAfter = ((_newMarketSkew - _newPositionSize) * 1e30) / int256(_maxSkewScale);

    int256 _premium = (_premiumBefore + _premiumAfter) / 2;

    if (_premium > 0) {
      return (_oraclePrice * (1e30 + uint256(_premium))) / 1e30;
    } else {
      return (_oraclePrice * (1e30 - uint256(-_premium))) / 1e30;
    }
  }

  /// @notice This function increases the reserve value
  /// @param _assetClassIndex The index of asset class.
  /// @param _reservedValue The amount by which to increase the reserve value.
  function _increaseReserved(uint8 _assetClassIndex, uint256 _reservedValue) private {
    // SLOAD
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the total TVL
    uint256 tvl = calculator.getPLPValueE30(true);

    // Retrieve the global state
    PerpStorage.GlobalState memory _globalState = _perpStorage.getGlobalState();

    // Retrieve the global asset class
    PerpStorage.AssetClass memory _assetClass = _perpStorage.getAssetClassByIndex(_assetClassIndex);

    // get the liquidity configuration
    ConfigStorage.LiquidityConfig memory _liquidityConfig = ConfigStorage(configStorage).getLiquidityConfig();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += _reservedValue;
    _assetClass.reserveValueE30 += _reservedValue;

    // Check if the new reserve value exceeds the % of AUM, and revert if it does
    if ((tvl * _liquidityConfig.maxPLPUtilizationBPS) < _globalState.reserveValueE30 * BPS) {
      revert ITradeService_InsufficientLiquidity();
    }

    // Update the new reserve value in the PerpStorage contract
    _perpStorage.updateGlobalState(_globalState);
    _perpStorage.updateAssetClass(_assetClassIndex, _assetClass);
  }

  /// @notice health check for sub account that equity > margin maintenance required
  /// @param _subAccount target sub account for health check
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function _subAccountHealthCheck(address _subAccount, uint256 _limitPriceE30, bytes32 _limitAssetId) private view {
    // SLOAD
    Calculator _calculator = calculator;

    // check sub account is healthy
    int256 _subAccountEquity = _calculator.getEquity(_subAccount, _limitPriceE30, _limitAssetId);

    // maintenance margin requirement (MMR) = position size * maintenance margin fraction
    // note: maintenanceMarginFractionBPS is 1e4
    uint256 _mmr = _calculator.getMMR(_subAccount);

    // if sub account equity < MMR, then trader couldn't increase position
    if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) revert ITradeService_SubAccountEquityIsUnderMMR();
  }

  function _increasePositionHooks(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _sizeDelta
  ) private {
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
  ) private {
    address[] memory _hooks = ConfigStorage(configStorage).getTradeServiceHooks();
    for (uint256 i; i < _hooks.length; ) {
      ITradeServiceHook(_hooks[i]).onDecreasePosition(_primaryAccount, _subAccountId, _marketIndex, _sizeDelta, "");
      unchecked {
        ++i;
      }
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
