// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";

import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { OrderbookOracle } from "@hmx/oracles/OrderbookOracle.sol";
import { AdaptiveFeeCalculator } from "@hmx/contracts/AdaptiveFeeCalculator.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract TradeHelper is ITradeHelper, ReentrancyGuardUpgradeable, OwnableUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;

  /**
   * Events
   */
  event LogSettleTradingFeeValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 feeUsd);
  event LogSettleTradingFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 protocolFeeAmount
  );
  event LogSettleBorrowingFeeValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 feeUsd);
  event LogSettleBorrowingFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 hlpFeeAmount
  );
  event LogSettleFundingFeeValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 feeUsd);
  event LogSettleFundingFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 amount
  );

  event LogSettleUnRealizedPnlValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 usd);
  event LogSettleUnRealizedPnlAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 usd,
    uint256 amount
  );

  event LogSettleLiquidationFeeValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 usd);
  event LogSettleLiquidationFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 usd,
    uint256 amount
  );

  event LogSettleSettlementFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 amount
  );

  event LogReceivedFundingFeeValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 feeUsd);
  event LogReceivedFundingFeeAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 amount
  );

  event LogReceivedUnRealizedPnlValue(bytes32 positionId, uint256 marketIndex, address subAccount, uint256 usd);
  event LogReceivedUnRealizedPnlAmount(
    bytes32 positionId,
    uint256 marketIndex,
    address subAccount,
    address token,
    uint256 usd,
    uint256 amount
  );

  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);
  event LogFundingRate(uint256 indexed marketIndex, int256 oldFundingRate, int256 newFundingRate);
  event LogSetAdaptiveFeeCalculator(address indexed oldAdaptiveFeeCalculator, address indexed adaptiveFeeCalculator);
  event LogSetOrderbookOracle(address indexed oldOrderbookOracle, address indexed orderbookOracle);
  event LogSetMaxAdaptiveFeeBps(uint32 indexed oldMaxAdaptiveFeeBps, uint32 indexed maxAdaptiveFeeBps);

  /**
   * Structs
   */
  struct IncreaseCollateralVars {
    bytes32 positionId;
    address token;
    address subAccount;
    uint8 tokenDecimal;
    uint256 unrealizedPnlToBeReceived;
    uint256 fundingFeeToBeReceived;
    uint256 payerBalance;
    uint256 tokenPrice;
    uint256 marketIndex;
    PerpStorage perpStorage;
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
  }

  struct DecreaseCollateralVars {
    bytes32 positionId;
    address token;
    address subAccount;
    uint8 tokenDecimal;
    uint256 unrealizedPnlToBePaid;
    uint256 tradingFeeToBePaid;
    uint256 borrowingFeeToBePaid;
    uint256 fundingFeeToBePaid;
    uint256 liquidationFeeToBePaid;
    uint256 payerBalance;
    uint256 hlpDebt;
    uint256 tokenPrice;
    uint256 marketIndex;
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    ConfigStorage.TradingConfig tradingConfig;
  }

  struct SettleAllFeeVars {
    address subAccount;
    uint256 tradingFeeToBePaid;
    uint256 borrowingFeeToBePaid;
    int256 fundingFeeToBePaid;
  }

  /**
   * Constants
   */
  uint32 internal constant BPS = 1e4;
  uint64 internal constant RATE_PRECISION = 1e18;

  /**
   * States
   */
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  Calculator public calculator; // cache this from configStorage
  OrderbookOracle public orderbookOracle;
  AdaptiveFeeCalculator public adaptiveFeeCalculator;
  uint32 public maxAdaptiveFeeBps;

  /// @notice Initializes the contract by setting the addresses for PerpStorage, VaultStorage, and ConfigStorage.
  /// @dev This function must be called after the contract is deployed and before it can be used.
  /// @param _perpStorage The address of the PerpStorage contract.
  /// @param _vaultStorage The address of the VaultStorage contract.
  /// @param _configStorage The address of the ConfigStorage contract.
  /// @dev This function initializes the contract by performing a sanity check on the ConfigStorage calculator, setting the VaultStorage devFees to address(0), and getting the global state from the PerpStorage contract. It also sets the perpStorage, vaultStorage, configStorage, and calculator variables to the provided addresses.

  function initialize(address _perpStorage, address _vaultStorage, address _configStorage) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Sanity check
    ConfigStorage(_configStorage).calculator();
    VaultStorage(_vaultStorage).devFees(address(0));
    PerpStorage(_perpStorage).getGlobalState();

    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = Calculator(ConfigStorage(_configStorage).calculator());
  }

  /**
   * Modifiers
   */
  // NOTE: Validate only whitelisted contract be able to call this function
  modifier onlyWhitelistedExecutor() {
    ConfigStorage(configStorage).validateServiceExecutor(address(this), msg.sender);
    _;
  }

  /**
   * Core Functions
   */
  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  function updateBorrowingRate(uint8 _assetClassIndex) external nonReentrant onlyWhitelistedExecutor {
    // SLOAD
    Calculator _calculator = calculator;
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.AssetClass memory _assetClass = _perpStorage.getAssetClassByIndex(_assetClassIndex);
    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastBorrowingTime = _assetClass.lastBorrowingTime;

    // If last borrowing time is 0, set it to the nearest funding interval time and return.
    if (_lastBorrowingTime == 0) {
      _assetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateAssetClass(_assetClassIndex, _assetClass);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastBorrowingTime + _fundingInterval <= block.timestamp) {
      uint256 _hlpTVL = _calculator.getHLPValueE30(false);

      // update borrowing rate
      uint256 borrowingRate = _calculator.getNextBorrowingRate(_assetClassIndex, _hlpTVL);
      _assetClass.sumBorrowingRate += borrowingRate;
      _assetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      uint256 borrowingFee = (_assetClass.reserveValueE30 * borrowingRate) / RATE_PRECISION;
      _assetClass.sumBorrowingFeeE30 += borrowingFee;

      _perpStorage.updateAssetClass(_assetClassIndex, _assetClass);
    }
  }

  /// @notice This function updates the funding rate for the given market index.
  /// @param _marketIndex The index of the market.
  function updateFundingRate(uint256 _marketIndex) external nonReentrant onlyWhitelistedExecutor {
    // SLOAD
    Calculator _calculator = calculator;
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    // Get the funding interval, asset class config, and global asset class for the given asset class index.
    PerpStorage.Market memory _market = _perpStorage.getMarketByIndex(_marketIndex);

    uint256 _fundingInterval = ConfigStorage(configStorage).getTradingConfig().fundingInterval;
    uint256 _lastFundingTime = _market.lastFundingTime;

    // If last funding time is 0, set it to the nearest funding interval time and return.
    if (_lastFundingTime == 0) {
      _market.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateMarket(_marketIndex, _market);
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (_lastFundingTime + _fundingInterval <= block.timestamp) {
      // update funding rate
      int256 proportionalElapsedInDay = int256(_calculator.proportionalElapsedInDay(_marketIndex));
      int256 nextFundingRate = _market.currentFundingRate +
        ((_calculator.getFundingRateVelocity(_marketIndex) * proportionalElapsedInDay) / 1e18);
      int256 lastFundingAccrued = _market.fundingAccrued;
      _market.fundingAccrued += ((_market.currentFundingRate + nextFundingRate) * proportionalElapsedInDay) / 2 / 1e18;

      if (_market.longPositionSize > 0) {
        int256 fundingFeeLongE30 = _calculator.getFundingFee(
          int256(_market.longPositionSize),
          _market.fundingAccrued,
          lastFundingAccrued
        );
        _market.accumFundingLong += fundingFeeLongE30;
      }

      if (_market.shortPositionSize > 0) {
        int256 fundingFeeShortE30 = _calculator.getFundingFee(
          -int256(_market.shortPositionSize),
          _market.fundingAccrued,
          lastFundingAccrued
        );
        _market.accumFundingShort += fundingFeeShortE30;
      }

      emit LogFundingRate(_marketIndex, _market.currentFundingRate, nextFundingRate);
      _market.currentFundingRate = nextFundingRate;
      _market.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateMarket(_marketIndex, _market);
    }
  }

  /// @notice Settles all fees for a given position and updates the fee states.
  /// @param _positionId The ID of the position to settle fees for.
  /// @param _position The Position object for the position to settle fees for.
  /// @param _sizeDelta The value of the size delta for the position.
  /// @param _positionFeeBPS The position fee basis points for the position.
  /// @param _assetClassIndex The index of the asset class for the position.
  function settleAllFees(
    bytes32 _positionId,
    PerpStorage.Position memory _position,
    int256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex
  ) external nonReentrant onlyWhitelistedExecutor {
    SettleAllFeeVars memory _vars;
    _vars.subAccount = HMXLib.getSubAccount(_position.primaryAccount, _position.subAccountId);

    // update fee
    (_vars.tradingFeeToBePaid, _vars.borrowingFeeToBePaid, _vars.fundingFeeToBePaid) = _updateFeeStates(
      _positionId,
      _vars.subAccount,
      _position,
      _sizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _position.marketIndex,
      ConfigStorage(configStorage).isAdaptiveFeeEnabledByMarketIndex(_position.marketIndex)
    );

    // increase collateral
    _increaseCollateral(_positionId, _vars.subAccount, 0, _vars.fundingFeeToBePaid, address(0), _position.marketIndex);

    // decrease collateral
    _decreaseCollateral(
      _positionId,
      _vars.subAccount,
      0,
      _vars.fundingFeeToBePaid,
      _vars.borrowingFeeToBePaid,
      _vars.tradingFeeToBePaid,
      0,
      address(0),
      _position.marketIndex
    );
  }

  function updateFeeStates(
    bytes32 _positionId,
    address _subAccount,
    IPerpStorage.Position memory _position,
    int256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex,
    bool isAdaptiveFee
  )
    external
    nonReentrant
    onlyWhitelistedExecutor
    returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee)
  {
    (_tradingFee, _borrowingFee, _fundingFee) = _updateFeeStates(
      _positionId,
      _subAccount,
      _position,
      _sizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _marketIndex,
      isAdaptiveFee
    );
  }

  function accumSettledBorrowingFee(
    uint256 _assetClassIndex,
    uint256 _borrowingFeeToBeSettled
  ) external nonReentrant onlyWhitelistedExecutor {
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFeeToBeSettled);
  }

  function increaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    address _tpToken,
    uint256 _marketIndex
  ) external nonReentrant onlyWhitelistedExecutor {
    _increaseCollateral(_positionId, _subAccount, _unrealizedPnl, _fundingFee, _tpToken, _marketIndex);
  }

  function decreaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator,
    uint256 _marketIndex
  ) external nonReentrant onlyWhitelistedExecutor {
    _decreaseCollateral(
      _positionId,
      _subAccount,
      _unrealizedPnl,
      _fundingFee,
      _borrowingFee,
      _tradingFee,
      _liquidationFee,
      _liquidator,
      _marketIndex
    );
  }

  function reloadConfig() external nonReentrant onlyOwner {
    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  /**
   * Private Functions
   */

  function _updateFeeStates(
    bytes32 /*_positionId*/,
    address /*_subAccount*/,
    PerpStorage.Position memory _position,
    int256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex,
    bool _isAdaptiveFee
  ) internal returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) {
    // SLOAD
    Calculator _calculator = calculator;
    uint256 _absSizeDelta = HMXLib.abs(_sizeDelta);

    // Calculate the trading fee
    if (_isAdaptiveFee) {
      _positionFeeBPS = getAdaptiveFeeBps(_sizeDelta, _position.marketIndex, _positionFeeBPS);
    }

    _tradingFee = (_absSizeDelta * _positionFeeBPS) / BPS;

    // Calculate the borrowing fee
    _borrowingFee = _calculator.getBorrowingFee(
      _assetClassIndex,
      _position.reserveValueE30,
      _position.entryBorrowingRate
    );
    // Update global state
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFee);

    // Calculate the funding fee
    // We are assuming that the market state has been updated with the latest funding rate
    bool _isLong = _position.positionSizeE30 > 0;
    _fundingFee = _calculator.getFundingFee(
      _position.positionSizeE30,
      PerpStorage(perpStorage).getMarketByIndex(_marketIndex).fundingAccrued,
      _position.lastFundingAccrued
    );

    // Update global state
    _isLong
      ? _updateAccumFundingLong(_marketIndex, -_fundingFee)
      : _updateAccumFundingShort(_marketIndex, -_fundingFee);

    return (_tradingFee, _borrowingFee, _fundingFee);
  }

  function _accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) internal {
    // SLOAD
    PerpStorage _perpStorage = PerpStorage(perpStorage);

    PerpStorage.AssetClass memory _assetClass = _perpStorage.getAssetClassByIndex(uint8(_assetClassIndex));
    _assetClass.sumSettledBorrowingFeeE30 += _borrowingFeeToBeSettled;
    _perpStorage.updateAssetClass(uint8(_assetClassIndex), _assetClass);
  }

  function _increaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    address _tpToken,
    uint256 _marketIndex
  ) internal {
    IncreaseCollateralVars memory _vars;
    // SLOAD
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    _vars.positionId = _positionId;
    _vars.subAccount = _subAccount;
    _vars.marketIndex = _marketIndex;

    // check unrealized pnl
    if (_unrealizedPnl > 0) {
      _vars.unrealizedPnlToBeReceived = uint256(_unrealizedPnl);
      emit LogReceivedUnRealizedPnlValue(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.unrealizedPnlToBeReceived
      );
    }
    // check funding fee
    if (_fundingFee < 0) {
      _vars.fundingFeeToBeReceived = uint256(-_fundingFee);
      emit LogReceivedFundingFeeValue(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.fundingFeeToBeReceived
      );
    }

    // Pay trader with selected tp token
    {
      if (_tpToken != address(0)) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfigByToken(_tpToken);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;

        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);
        _vars.payerBalance = _vars.vaultStorage.hlpLiquidity(_assetConfig.tokenAddress);

        // get profit from hlp
        _increaseCollateralWithUnrealizedPnlFromHlp(_vars);
      }
    }

    bytes32[] memory _hlpAssetIds = _vars.configStorage.getHlpAssetIds();
    uint256 _len = _hlpAssetIds.length;
    {
      // loop for get fee from fee reserve
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_hlpAssetIds[i]);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;
        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

        _vars.payerBalance = _vars.vaultStorage.fundingFeeReserve(_assetConfig.tokenAddress);

        // get fee from fee reserve
        _increaseCollateralWithFundingFeeFromFeeReserve(_vars);

        unchecked {
          ++i;
        }
      }
    }
    {
      // loop for get fee and profit from hlp
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_hlpAssetIds[i]);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;
        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

        _vars.payerBalance = _vars.vaultStorage.hlpLiquidity(_assetConfig.tokenAddress);

        // get profit from hlp
        _increaseCollateralWithUnrealizedPnlFromHlp(_vars);
        // get fee from hlp
        _increaseCollateralWithFundingFeeFromHlp(_vars);

        unchecked {
          ++i;
        }
      }
    }
  }

  function _increaseCollateralWithUnrealizedPnlFromHlp(IncreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBeReceived > 0) {
      // We are going to deduct funding fee balance,
      // so we need to check whether funding fee has this collateral token or not.
      // If not skip to next token
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.unrealizedPnlToBeReceived,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // Calculate for settlement fee
      uint256 _settlementFeeRate = calculator.getSettlementFeeRate(_vars.token, _repayValue);
      uint256 _settlementFeeAmount = (_repayAmount * _settlementFeeRate) / 1e18;
      uint256 _settlementFeeValue = (_repayValue * _settlementFeeRate) / 1e18;

      // book the balances
      _vars.vaultStorage.payTraderProfit(_vars.subAccount, _vars.token, _repayAmount, _settlementFeeAmount);

      emit LogSettleSettlementFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _settlementFeeValue,
        _settlementFeeAmount
      );

      // deduct _vars.unrealizedPnlToBeReceived with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.unrealizedPnlToBeReceived -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      emit LogReceivedUnRealizedPnlAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _increaseCollateralWithFundingFeeFromFeeReserve(IncreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceived > 0) {
      // We are going to deduct funding fee balance,
      // so we need to check whether funding fee has this collateral token or not.
      // If not skip to next token
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.fundingFeeToBeReceived,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );

      // book the balances
      _vars.vaultStorage.payFundingFeeFromFundingFeeReserveToTrader(_vars.subAccount, _vars.token, _repayAmount);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBeReceived -= _repayValue;

      emit LogReceivedFundingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _increaseCollateralWithFundingFeeFromHlp(IncreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceived > 0) {
      // We are going to deduct hlp liquidity balance,
      // so we need to check whether hlp has this collateral token or not.
      // If not skip to next token
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.fundingFeeToBeReceived,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // book the balances
      _vars.vaultStorage.borrowFundingFeeFromHlpToTrader(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBeReceived -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      emit LogReceivedFundingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _decreaseCollateral(
    bytes32 _positionId,
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator,
    uint256 _marketIndex
  ) internal {
    DecreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    _vars.positionId = _positionId;
    _vars.subAccount = _subAccount;
    _vars.marketIndex = _marketIndex;

    bytes32[] memory _hlpAssetIds = _vars.configStorage.getHlpAssetIds();
    uint256 _len = _hlpAssetIds.length;

    // check loss
    if (_unrealizedPnl < 0) {
      emit LogSettleUnRealizedPnlValue(_vars.positionId, _vars.marketIndex, _vars.subAccount, uint256(-_unrealizedPnl));
      _vars.vaultStorage.addLossDebt(_subAccount, uint256(-_unrealizedPnl));
    }
    _vars.unrealizedPnlToBePaid = _vars.vaultStorage.lossDebt(_subAccount);

    // check trading fee
    _vars.vaultStorage.addTradingFeeDebt(_subAccount, _tradingFee);
    _vars.tradingFeeToBePaid = _vars.vaultStorage.tradingFeeDebt(_subAccount);

    // check borrowing fee
    _vars.vaultStorage.addBorrowingFeeDebt(_subAccount, _borrowingFee);
    _vars.borrowingFeeToBePaid = _vars.vaultStorage.borrowingFeeDebt(_subAccount);

    // check funding fee
    if (_fundingFee > 0) {
      emit LogSettleFundingFeeValue(_vars.positionId, _vars.marketIndex, _vars.subAccount, uint256(_fundingFee));
      _vars.vaultStorage.addFundingFeeDebt(_subAccount, uint256(_fundingFee));
    }
    _vars.fundingFeeToBePaid = _vars.vaultStorage.fundingFeeDebt(_subAccount);

    // check liquidation fee
    _vars.liquidationFeeToBePaid = _liquidationFee;

    emit LogSettleTradingFeeValue(_vars.positionId, _vars.marketIndex, _vars.subAccount, _tradingFee);
    emit LogSettleBorrowingFeeValue(_vars.positionId, _vars.marketIndex, _vars.subAccount, _borrowingFee);
    emit LogSettleLiquidationFeeValue(_vars.positionId, _vars.marketIndex, _vars.subAccount, _liquidationFee);

    // loop for settle
    for (uint256 i = 0; i < _len; ) {
      ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_hlpAssetIds[i]);
      _vars.tokenDecimal = _assetConfig.decimals;
      _vars.token = _assetConfig.tokenAddress;
      (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

      _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
      _vars.hlpDebt = _vars.vaultStorage.hlpLiquidityDebtUSDE30();
      // settle liquidation fee
      _decreaseCollateralWithLiquidationFee(_vars, _liquidator);
      // settle borrowing fee
      _decreaseCollateralWithBorrowingFeeToHlp(_vars);
      // settle trading fee
      _decreaseCollateralWithTradingFeeToProtocolFee(_vars);
      // settle funding fee to hlp
      _decreaseCollateralWithFundingFeeToHlp(_vars);
      // settle funding fee to fee reserve
      _decreaseCollateralWithFundingFeeToFeeReserve(_vars);
      // settle loss fee
      _decreaseCollateralWithUnrealizedPnlToHlp(_vars);

      unchecked {
        ++i;
      }
    }
  }

  function _decreaseCollateralWithUnrealizedPnlToHlp(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.unrealizedPnlToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      VaultStorage(_vars.vaultStorage).payHlp(_vars.subAccount, _vars.token, _repayAmount);

      _vars.unrealizedPnlToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subLossDebt(_vars.subAccount, _repayValue);

      emit LogSettleUnRealizedPnlAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _decreaseCollateralWithFundingFeeToHlp(DecreaseCollateralVars memory _vars) internal {
    // If absFundingFeeToBePaid is less than borrowing debts from HLP, Then Trader repay with all current collateral amounts to HLP
    // Else Trader repay with just enough current collateral amounts to HLP
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0 && _vars.hlpDebt > 0) {
      // Trader repay with just enough current collateral amounts to HLP
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.fundingFeeToBePaid > _vars.hlpDebt ? _vars.hlpDebt : _vars.fundingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // book the balances
      _vars.vaultStorage.repayFundingFeeDebtFromTraderToHlp(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subFundingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleFundingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _decreaseCollateralWithFundingFeeToFeeReserve(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0) {
      // We are going to deduct trader balance,
      // so we need to check whether trader has this collateral token or not.
      // If not skip to next token
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.fundingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // book the balances
      _vars.vaultStorage.payFundingFeeFromTraderToFundingFeeReserve(_vars.subAccount, _vars.token, _repayAmount);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subFundingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleFundingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _decreaseCollateralWithTradingFeeToProtocolFee(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.tradingFeeToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.tradingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // devFee = tradingFee * devFeeRate
      uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
      // the rest after dev fee deduction belongs to protocol fee portion
      uint256 _protocolFeeAmount = _repayAmount - _devFeeAmount;

      // book those moving balances
      _vars.vaultStorage.payTradingFee(_vars.subAccount, _vars.token, _devFeeAmount, _protocolFeeAmount);

      // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.tradingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subTradingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleTradingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _devFeeAmount,
        _protocolFeeAmount
      );
    }
  }

  function _decreaseCollateralWithBorrowingFeeToHlp(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.borrowingFeeToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.borrowingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // devFee = tradingFee * devFeeRate
      uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
      // the rest after dev fee deduction belongs to hlp liquidity
      uint256 _hlpFeeAmount = _repayAmount - _devFeeAmount;

      // book those moving balances
      _vars.vaultStorage.payBorrowingFee(_vars.subAccount, _vars.token, _devFeeAmount, _hlpFeeAmount);

      // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.borrowingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subBorrowingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleBorrowingFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _devFeeAmount,
        _hlpFeeAmount
      );
    }
  }

  function _decreaseCollateralWithLiquidationFee(DecreaseCollateralVars memory _vars, address _liquidator) internal {
    if (_vars.payerBalance > 0 && _vars.liquidationFeeToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.liquidationFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      _vars.vaultStorage.transfer(_vars.token, _vars.subAccount, _liquidator, _repayAmount);

      _vars.liquidationFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      emit LogSettleLiquidationFeeAmount(
        _vars.positionId,
        _vars.marketIndex,
        _vars.subAccount,
        _vars.token,
        _repayValue,
        _repayAmount
      );
    }
  }

  function _getRepayAmount(
    uint256 _payerBalance,
    uint256 _valueE30,
    uint256 _tokenPrice,
    uint8 _tokenDecimal
  ) internal pure returns (uint256 _repayAmount, uint256 _repayValueE30) {
    uint256 _feeAmount = (_valueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_payerBalance > _feeAmount) {
      // _payerBalance can cover the rest of the fee
      return (_feeAmount, _valueE30);
    } else {
      // _payerBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _payerBalanceValue = (_payerBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_payerBalance, _payerBalanceValue);
    }
  }

  function _updateAccumFundingLong(uint256 _marketIndex, int256 fundingLong) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.Market memory _market = _perpStorage.getMarketByIndex(_marketIndex);

    _market.accumFundingLong += fundingLong;
    _perpStorage.updateMarket(_marketIndex, _market);
  }

  function _updateAccumFundingShort(uint256 _marketIndex, int256 fundingShort) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.Market memory _market = _perpStorage.getMarketByIndex(_marketIndex);

    _market.accumFundingShort += fundingShort;
    _perpStorage.updateMarket(_marketIndex, _market);
  }

  /**
   * Setter
   */
  /// @notice Set new ConfigStorage contract address.
  /// @param _configStorage New ConfigStorage contract address.
  function setConfigStorage(address _configStorage) external nonReentrant onlyOwner {
    if (_configStorage == address(0)) revert ITradeHelper_InvalidAddress();
    emit LogSetConfigStorage(configStorage, _configStorage);
    configStorage = _configStorage;

    // Sanity check
    ConfigStorage(_configStorage).calculator();
  }

  /// @notice Set new VaultStorage contract address.
  /// @param _vaultStorage New VaultStorage contract address.
  function setVaultStorage(address _vaultStorage) external nonReentrant onlyOwner {
    if (_vaultStorage == address(0)) revert ITradeHelper_InvalidAddress();

    emit LogSetVaultStorage(vaultStorage, _vaultStorage);
    vaultStorage = _vaultStorage;

    // Sanity check
    VaultStorage(_vaultStorage).devFees(address(0));
  }

  /// @notice Set new PerpStorage contract address.
  /// @param _perpStorage New PerpStorage contract address.
  function setPerpStorage(address _perpStorage) external nonReentrant onlyOwner {
    if (_perpStorage == address(0)) revert ITradeHelper_InvalidAddress();

    emit LogSetPerpStorage(perpStorage, _perpStorage);
    perpStorage = _perpStorage;

    // Sanity check
    PerpStorage(_perpStorage).getGlobalState();
  }

  function getAdaptiveFeeBps(
    int256 _sizeDelta,
    uint256 _marketIndex,
    uint32 _baseFeeBps
  ) public view returns (uint32 feeBps) {
    (uint256 askDepth, uint256 bidDepth, uint256 coeffVariants) = orderbookOracle.getData(_marketIndex);
    bool isBuy = _sizeDelta > 0;
    uint256 epochOI = PerpStorage(perpStorage).getEpochVolume(isBuy, _marketIndex);
    feeBps = adaptiveFeeCalculator.getAdaptiveFeeBps(
      HMXLib.abs(_sizeDelta) / 1e22,
      epochOI / 1e22,
      isBuy ? askDepth : bidDepth,
      coeffVariants,
      _baseFeeBps,
      maxAdaptiveFeeBps
    );
  }

  function setAdaptiveFeeCalculator(address _adaptiveFeeCalculator) external onlyOwner {
    emit LogSetAdaptiveFeeCalculator(address(adaptiveFeeCalculator), _adaptiveFeeCalculator);
    adaptiveFeeCalculator = AdaptiveFeeCalculator(_adaptiveFeeCalculator);
  }

  function setOrderbookOracle(address _orderbookOracle) external onlyOwner {
    emit LogSetOrderbookOracle(address(orderbookOracle), _orderbookOracle);
    orderbookOracle = OrderbookOracle(_orderbookOracle);
  }

  function setMaxAdaptiveFeeBps(uint32 _maxAdaptiveFeeBps) external onlyOwner {
    emit LogSetMaxAdaptiveFeeBps(maxAdaptiveFeeBps, _maxAdaptiveFeeBps);
    maxAdaptiveFeeBps = _maxAdaptiveFeeBps;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
