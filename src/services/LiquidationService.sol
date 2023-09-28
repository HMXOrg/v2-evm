// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// contracts
import { FullMath } from "@hmx/libraries/FullMath.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { TradeHelper } from "@hmx/helpers/TradeHelper.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

// interfaces
import { ILiquidationService } from "./interfaces/ILiquidationService.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";

/// @title LiquidationService
/// @dev This contract implements the ILiquidationService interface and provides functionality for liquidating sub-accounts by resetting their positions' value in storage.
contract LiquidationService is ReentrancyGuardUpgradeable, ILiquidationService, OwnableUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;
  using FullMath for uint256;

  /**
   * Events
   */
  event LogLiquidation(
    address indexed subAccount,
    int256 equity,
    uint256 mmr,
    uint256 tradingFee,
    uint256 borrowingFee,
    int256 fundingFee,
    uint256 liquidationFee,
    int256 unrealizedPnL
  );

  event LogLiquidationPosition(
    bytes32 indexed positionId,
    address indexed account,
    uint8 subAccountId,
    uint256 marketIndex,
    int256 size,
    bool isProfit,
    uint256 delta
  );

  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogSetTradeHelper(address indexed oldTradeHelper, address newTradeHelper);

  /**
   * Structs
   */

  struct LiquidateVars {
    uint256 mmr;
    uint256 tradingFee;
    uint256 borrowingFee;
    uint256 liquidationFeeUSDE30;
    int256 equity;
    int256 fundingFee;
    int256 unrealizedPnL;
    VaultStorage vaultStorage;
    TradeHelper tradeHelper;
    Calculator calculator;
    ConfigStorage configStorage;
  }

  struct LiquidatePositionVars {
    bytes32 positionId;
    uint256 absPositionSizeE30;
    uint256 oldSumSe;
    uint256 oldSumS2e;
    uint256 tradingFee;
    uint256 borrowingFee;
    int256 fundingFee;
    bool isLong;
    IPerpStorage.Position position;
    PerpStorage.Market globalMarket;
    ConfigStorage.MarketConfig marketConfig;
    VaultStorage vaultStorage;
    TradeHelper tradeHelper;
    PerpStorage perpStorage;
    OracleMiddleware oracle;
    Calculator calculator;
    ConfigStorage configStorage;
  }

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public tradeHelper;
  Calculator public calculator;

  /// @notice Initializes the LiquidationService contract by setting the initial values for the contracts used by this service.
  /// @dev This function should be called only once during contract deployment.
  /// @param _perpStorage The address of the PerpStorage contract.
  /// @param _vaultStorage The address of the VaultStorage contract.
  /// @param _configStorage The address of the ConfigStorage contract.
  /// @param _tradeHelper The address of the TradeHelper contract.
  function initialize(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _tradeHelper
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    tradeHelper = _tradeHelper;

    calculator = Calculator(ConfigStorage(configStorage).calculator());

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
    VaultStorage(_vaultStorage).hlpLiquidityDebtUSDE30();
    ConfigStorage(_configStorage).getLiquidityConfig();
    TradeHelper(_tradeHelper).perpStorage();
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

  /// @notice Liquidates a sub-account by settling its positions and resetting its value in storage
  /// @param _subAccount The sub-account to be liquidated
  function liquidate(address _subAccount, address _liquidator) external onlyWhitelistedExecutor {
    LiquidateVars memory _vars;
    // SLOAD
    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(_vars.configStorage.calculator());

    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    _vars.equity = _vars.calculator.getEquity(_subAccount, 0, 0);
    _vars.mmr = _vars.calculator.getMMR(_subAccount);
    if (_vars.equity >= 0 && uint256(_vars.equity) >= _vars.mmr) revert ILiquidationService_AccountHealthy();

    // Liquidate the positions by resetting their value in storage
    (_vars.tradingFee, _vars.borrowingFee, _vars.fundingFee, _vars.unrealizedPnL) = _liquidatePosition(_subAccount);

    _vars.liquidationFeeUSDE30 = _vars.configStorage.getLiquidationConfig().liquidationFeeUSDE30;

    // get profit and fee
    _vars.tradeHelper.increaseCollateral(
      bytes32(0),
      _subAccount,
      _vars.unrealizedPnL,
      _vars.fundingFee,
      address(0),
      type(uint256).max
    );
    // settle fee and loss
    _vars.tradeHelper.decreaseCollateral(
      bytes32(0),
      _subAccount,
      _vars.unrealizedPnL,
      _vars.fundingFee,
      _vars.borrowingFee,
      _vars.tradingFee,
      _vars.liquidationFeeUSDE30,
      _liquidator,
      type(uint256).max
    );

    // do accounting on sub account
    _vars.vaultStorage.subLossDebt(_subAccount, _vars.vaultStorage.lossDebt(_subAccount));
    _vars.vaultStorage.subTradingFeeDebt(_subAccount, _vars.vaultStorage.tradingFeeDebt(_subAccount));
    _vars.vaultStorage.subBorrowingFeeDebt(_subAccount, _vars.vaultStorage.borrowingFeeDebt(_subAccount));
    _vars.vaultStorage.subFundingFeeDebt(_subAccount, _vars.vaultStorage.fundingFeeDebt(_subAccount));

    emit LogLiquidation(
      _subAccount,
      _vars.equity,
      _vars.mmr,
      _vars.tradingFee,
      _vars.borrowingFee,
      _vars.fundingFee,
      _vars.liquidationFeeUSDE30,
      _vars.unrealizedPnL
    );
  }

  function reloadConfig() external nonReentrant onlyOwner {
    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /**
   * Setters
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }

  /// @notice Set new Calculator contract address.
  /// @param _calculator New Calculator contract address.
  function setCalculator(address _calculator) external nonReentrant onlyOwner {
    if (_calculator == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetCalculator(address(calculator), _calculator);
    calculator = Calculator(_calculator);

    // Sanity check
    Calculator(_calculator).oracle();
  }

  /// @notice Set new TradeHelper contract address.
  /// @param _tradeHelper New TradeHelper contract address.
  function setTradeHelper(address _tradeHelper) external nonReentrant onlyOwner {
    if (_tradeHelper == address(0)) revert ILiquidationService_InvalidAddress();
    emit LogSetTradeHelper(tradeHelper, _tradeHelper);
    tradeHelper = _tradeHelper;

    // Sanity check
    TradeHelper(_tradeHelper).perpStorage();
  }

  /**
   * Private Functions
   */

  /// @dev Liquidates positions associated with a given sub-account.
  /// It iterates over the list of position IDs and updates borrowing rate,
  /// funding rate, fee states, global state, and market price for each position.
  /// It also calculates realized and unrealized P&L for each position and
  /// decreases the position size, reserved value, and removes the position from storage.
  /// @param _subAccount The address of the sub-account to liquidate.
  /// @return tradingFee The total trading fee incurred for all liquidated positions.
  /// @return borrowingFee The total borrowing fee incurred for all liquidated positions.
  /// @return fundingFee The total funding fee incurred for all liquidated positions.
  /// @return _unrealizedPnL The total unrealized P&L for all liquidated positions.
  function _liquidatePosition(
    address _subAccount
  ) private returns (uint256 tradingFee, uint256 borrowingFee, int256 fundingFee, int256 _unrealizedPnL) {
    LiquidatePositionVars memory _vars;
    // SLOAD
    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.perpStorage = PerpStorage(perpStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(calculator);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    // Get the list of position ids associated with the sub-account
    bytes32[] memory positionIds = _vars.perpStorage.getPositionIds(_subAccount);

    uint256 _len = positionIds.length;
    for (uint256 i; i < _len; ) {
      // Get the current position id from the list
      _vars.positionId = positionIds[i];
      _vars.position = _vars.perpStorage.getPositionById(_vars.positionId);
      _vars.absPositionSizeE30 = HMXLib.abs(_vars.position.positionSizeE30);

      _vars.isLong = _vars.position.positionSizeE30 > 0;

      _vars.marketConfig = _vars.configStorage.getMarketConfigByIndex(_vars.position.marketIndex);

      // Update borrowing rate
      _vars.tradeHelper.updateBorrowingRate(_vars.marketConfig.assetClass);
      // Update funding rate
      _vars.tradeHelper.updateFundingRate(_vars.position.marketIndex);

      // Update fees
      {
        (_vars.tradingFee, _vars.borrowingFee, _vars.fundingFee) = _vars.tradeHelper.updateFeeStates(
          _vars.positionId,
          _subAccount,
          _vars.position,
          -_vars.position.positionSizeE30,
          _vars.marketConfig.decreasePositionFeeRateBPS,
          _vars.marketConfig.assetClass,
          _vars.position.marketIndex,
          _vars.marketConfig.isAdaptiveFeeEnabled
        );
        tradingFee += _vars.tradingFee;
        borrowingFee += _vars.borrowingFee;
        fundingFee += _vars.fundingFee;
      }

      _vars.oldSumSe = _vars.absPositionSizeE30.mulDiv(1e30, _vars.position.avgEntryPriceE30);
      _vars.oldSumS2e = _vars.absPositionSizeE30.mulDiv(_vars.absPositionSizeE30, _vars.position.avgEntryPriceE30);
      _vars.globalMarket = _vars.perpStorage.getMarketByIndex(_vars.position.marketIndex);

      (uint256 _adaptivePrice, ) = _vars.oracle.getLatestAdaptivePrice(
        _vars.marketConfig.assetId,
        _vars.isLong,
        (int(_vars.globalMarket.longPositionSize) - int(_vars.globalMarket.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _vars.marketConfig.fundingRate.maxSkewScaleUSD,
        0 // liquidation always has no limitedPrice
      );

      // Update global state
      {
        int256 _realizedPnl;
        uint256 absPositionSize = HMXLib.abs(_vars.position.positionSizeE30);

        (bool _isProfit, uint256 _delta) = _vars.calculator.getDelta(
          absPositionSize,
          _vars.position.positionSizeE30 > 0,
          _adaptivePrice,
          _vars.position.avgEntryPriceE30,
          _vars.position.lastIncreaseTimestamp,
          _vars.position.marketIndex
        );

        // if trader has profit more than reserved value then trader's profit maximum is reserved value
        if (_isProfit && _delta >= _vars.position.reserveValueE30) {
          _delta = _vars.position.reserveValueE30;
        }

        _realizedPnl = _isProfit ? int256(_delta) : -int256(_delta);
        _unrealizedPnL += _realizedPnl;

        _vars.perpStorage.decreaseReserved(_vars.marketConfig.assetClass, _vars.position.reserveValueE30);

        _decreasePositionHooks(
          _vars.position.primaryAccount,
          _vars.position.subAccountId,
          _vars.position.marketIndex,
          absPositionSize
        );

        // remove the position's value in storage
        _vars.perpStorage.removePositionFromSubAccount(_subAccount, _vars.positionId);

        emit LogLiquidationPosition(
          _vars.positionId,
          _vars.position.primaryAccount,
          _vars.position.subAccountId,
          _vars.position.marketIndex,
          _vars.position.positionSizeE30,
          _isProfit,
          _delta
        );
      }

      // Update counter trade states
      {
        if (_vars.isLong) {
          _vars.perpStorage.updateGlobalLongMarketById(
            _vars.position.marketIndex,
            _vars.globalMarket.longPositionSize - _vars.absPositionSizeE30,
            _vars.position.avgEntryPriceE30 > 0 ? (_vars.globalMarket.longAccumSE - _vars.oldSumSe) : 0,
            _vars.position.avgEntryPriceE30 > 0 ? (_vars.globalMarket.longAccumS2E - _vars.oldSumS2e) : 0
          );
          _vars.perpStorage.decreaseEpochOI(true, _vars.position.marketIndex, _vars.absPositionSizeE30);
        } else {
          _vars.perpStorage.updateGlobalShortMarketById(
            _vars.position.marketIndex,
            _vars.globalMarket.shortPositionSize - _vars.absPositionSizeE30,
            _vars.position.avgEntryPriceE30 > 0 ? (_vars.globalMarket.shortAccumSE - _vars.oldSumSe) : 0,
            _vars.position.avgEntryPriceE30 > 0 ? (_vars.globalMarket.shortAccumS2E - _vars.oldSumS2e) : 0
          );
          _vars.perpStorage.decreaseEpochOI(false, _vars.position.marketIndex, _vars.absPositionSizeE30);
        }
      }

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
