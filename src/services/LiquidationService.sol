// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// contracts
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

/// @title LiquidationService
/// @dev This contract implements the ILiquidationService interface and provides functionality for liquidating sub-accounts by resetting their positions' value in storage.
contract LiquidationService is ReentrancyGuardUpgradeable, ILiquidationService, OwnableUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;

  /**
   * Events
   */
  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogSetTradeHelper(address indexed oldTradeHelper, address newTradeHelper);

  /**
   * Structs
   */
  struct LiquidatePositionVars {
    bytes32 positionId;
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
    VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
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
    LiquidatePositionVars memory _vars;
    // SLOAD
    _vars.tradeHelper = TradeHelper(tradeHelper);
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.calculator = Calculator(_vars.configStorage.calculator());

    // If the equity is greater than or equal to the MMR, the account is healthy and cannot be liquidated
    int256 _equity = _vars.calculator.getEquity(_subAccount, 0, 0);
    if (_equity >= 0 && uint256(_equity) >= _vars.calculator.getMMR(_subAccount))
      revert ILiquidationService_AccountHealthy();

    // Liquidate the positions by resetting their value in storage
    (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee, int256 _unrealizedPnL) = _liquidatePosition(
      _subAccount
    );

    // get profit and fee
    _vars.tradeHelper.increaseCollateral(bytes32(0), _subAccount, _unrealizedPnL, _fundingFee, address(0));
    // settle fee and loss
    _vars.tradeHelper.decreaseCollateral(
      bytes32(0),
      _subAccount,
      _unrealizedPnL,
      _fundingFee,
      _borrowingFee,
      _tradingFee,
      _vars.configStorage.getLiquidationConfig().liquidationFeeUSDE30,
      _liquidator
    );

    // do accounting on sub account
    _vars.vaultStorage.subLossDebt(_subAccount, _vars.vaultStorage.lossDebt(_subAccount));
    _vars.vaultStorage.subTradingFeeDebt(_subAccount, _vars.vaultStorage.tradingFeeDebt(_subAccount));
    _vars.vaultStorage.subBorrowingFeeDebt(_subAccount, _vars.vaultStorage.borrowingFeeDebt(_subAccount));
    _vars.vaultStorage.subFundingFeeDebt(_subAccount, _vars.vaultStorage.fundingFeeDebt(_subAccount));
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
      bool _isLong = _vars.position.positionSizeE30 > 0;

      _vars.marketConfig = _vars.configStorage.getMarketConfigByIndex(_vars.position.marketIndex);

      // Update borrowing rate
      _vars.tradeHelper.updateBorrowingRate(_vars.marketConfig.assetClass);
      // Update funding rate
      _vars.tradeHelper.updateFundingRate(_vars.position.marketIndex);

      // Update fees
      {
        (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) = _vars.tradeHelper.updateFeeStates(
          _vars.positionId,
          _subAccount,
          _vars.position,
          HMXLib.abs(_vars.position.positionSizeE30),
          _vars.marketConfig.decreasePositionFeeRateBPS,
          _vars.marketConfig.assetClass,
          _vars.position.marketIndex
        );
        tradingFee += _tradingFee;
        borrowingFee += _borrowingFee;
        fundingFee += _fundingFee;
      }

      _vars.globalMarket = _vars.perpStorage.getMarketByIndex(_vars.position.marketIndex);

      (uint256 _adaptivePrice, ) = _vars.oracle.getLatestAdaptivePrice(
        _vars.marketConfig.assetId,
        _isLong,
        (int(_vars.globalMarket.longPositionSize) - int(_vars.globalMarket.shortPositionSize)),
        -_vars.position.positionSizeE30,
        _vars.marketConfig.fundingRate.maxSkewScaleUSD,
        0 // liquidation always has no limitedPrice
      );

      // Update global state
      {
        int256 _realizedPnl;
        uint256 absPositionSize = HMXLib.abs(_vars.position.positionSizeE30);
        {
          (bool _isProfit, uint256 _delta) = _vars.calculator.getDelta(
            absPositionSize,
            _vars.position.positionSizeE30 > 0,
            _adaptivePrice,
            _vars.position.avgEntryPriceE30,
            _vars.position.lastIncreaseTimestamp
          );

          // if trader has profit more than reserved value then trader's profit maximum is reserved value
          if (_isProfit && _delta >= _vars.position.reserveValueE30) {
            _delta = _vars.position.reserveValueE30;
          }

          _realizedPnl = _isProfit ? int256(_delta) : -int256(_delta);
          _unrealizedPnL += _realizedPnl;
        }

        _vars.perpStorage.decreasePositionSize(_vars.position.marketIndex, _isLong, absPositionSize);
        _vars.perpStorage.decreaseReserved(_vars.marketConfig.assetClass, _vars.position.reserveValueE30);

        // remove the position's value in storage
        _vars.perpStorage.removePositionFromSubAccount(_subAccount, _vars.positionId);
      }

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
