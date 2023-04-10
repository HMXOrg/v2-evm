// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";
import { Owned } from "@hmx/base/Owned.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

contract TradeHelper is ITradeHelper, ReentrancyGuard, Owned {
  /**
   * Events
   */
  event LogSettleTradingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleTradingFeeAmount(
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 protocolFeeAmount
  );
  event LogSettleBorrowingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleBorrowingFeeAmount(
    address subAccount,
    address token,
    uint256 feeUsd,
    uint256 devFeeAmount,
    uint256 plpFeeAmount
  );
  event LogSettleFundingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleFundingFeeAmount(address subAccount, address token, uint256 feeUsd, uint256 amount);

  event LogSettleUnRealizedPnlValue(address subAccount, uint256 usd);
  event LogSettleUnRealizedPnlAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogSettleLiquidationFeeValue(address subAccount, uint256 usd);
  event LogSettleLiquidationFeeAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogReceivedFundingFeeValue(address subAccount, uint256 feeUsd);
  event LogReceivedFundingFeeAmount(address subAccount, address token, uint256 feeUsd, uint256 amount);

  event LogReceivedUnRealizedPnlValue(address subAccount, uint256 usd);
  event LogReceivedUnRealizedPnlAmount(address subAccount, address token, uint256 usd, uint256 amount);

  event LogSetConfigStorage(address indexed oldConfigStorage, address newConfigStorage);
  event LogSetVaultStorage(address indexed oldVaultStorage, address newVaultStorage);
  event LogSetPerpStorage(address indexed oldPerpStorage, address newPerpStorage);

  /**
   * Structs
   */
  struct IncreaseCollateralVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    uint256 unrealizedPnlToBeReceived;
    uint256 fundingFeeToBeReceived;
    uint256 payerBalance;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
  }

  struct DecreaseCollateralVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    ConfigStorage.TradingConfig tradingConfig;
    uint256 unrealizedPnlToBePaid;
    uint256 tradingFeeToBePaid;
    uint256 borrowingFeeToBePaid;
    uint256 fundingFeeToBePaid;
    uint256 liquidationFeeToBePaid;
    uint256 payerBalance;
    uint256 plpDebt;
    uint256 tokenPrice;
    address subAccount;
    address token;
    uint8 tokenDecimal;
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

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
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
   * Core Funtions
   */
  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  function updateBorrowingRate(uint8 _assetClassIndex) external nonReentrant onlyWhitelistedExecutor {
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
      uint256 _plpTVL = calculator.getPLPValueE30(false);

      // update borrowing rate
      uint256 borrowingRate = calculator.getNextBorrowingRate(_assetClassIndex, _plpTVL);
      _assetClass.sumBorrowingRate += borrowingRate;
      _assetClass.lastBorrowingTime = (block.timestamp / _fundingInterval) * _fundingInterval;

      uint256 borrowingFee = (_assetClass.reserveValueE30 * borrowingRate) / RATE_PRECISION;

      _assetClass.sumBorrowingFeeE30 += borrowingFee;
    }
    _perpStorage.updateAssetClass(_assetClassIndex, _assetClass);
  }

  /// @notice This function updates the funding rate for the given market index.
  /// @param _marketIndex The index of the market.
  function updateFundingRate(uint256 _marketIndex) external nonReentrant onlyWhitelistedExecutor {
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
      int256 nextFundingRate = calculator.getNextFundingRate(_marketIndex);
      int256 lastFundingRate = _market.currentFundingRate;
      _market.currentFundingRate += nextFundingRate;
      _perpStorage.updateMarket(_marketIndex, _market);

      if (_market.longPositionSize > 0) {
        int256 fundingFeeLongE30 = calculator.getFundingFee(
          _marketIndex,
          true,
          int(_market.longPositionSize),
          lastFundingRate
        );
        _market.accumFundingLong += fundingFeeLongE30;
      }

      if (_market.shortPositionSize > 0) {
        int256 fundingFeeShortE30 = calculator.getFundingFee(
          _marketIndex,
          false,
          int(_market.shortPositionSize),
          lastFundingRate
        );
        _market.accumFundingShort += fundingFeeShortE30;
      }

      _market.lastFundingTime = (block.timestamp / _fundingInterval) * _fundingInterval;
      _perpStorage.updateMarket(_marketIndex, _market);
    }
  }

  function settleAllFees(
    PerpStorage.Position memory _position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external nonReentrant onlyWhitelistedExecutor {
    address _subAccount = _getSubAccount(_position.primaryAccount, _position.subAccountId);

    // update fee
    (uint256 _tradingFeeToBePaid, uint256 _borrowingFeeToBePaid, int256 _fundingFeeToBePaid) = _updateFeeStates(
      _subAccount,
      _position,
      _absSizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _marketIndex
    );

    // increase collateral
    _increaseCollateral(_subAccount, 0, _fundingFeeToBePaid);

    // decrease collateral
    _decreaseCollateral(_subAccount, 0, _fundingFeeToBePaid, _borrowingFeeToBePaid, _tradingFeeToBePaid, 0, address(0));
  }

  function updateFeeStates(
    address _subAccount,
    PerpStorage.Position memory _position,
    uint256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  )
    external
    nonReentrant
    onlyWhitelistedExecutor
    returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee)
  {
    (_tradingFee, _borrowingFee, _fundingFee) = _updateFeeStates(
      _subAccount,
      _position,
      _sizeDelta,
      _positionFeeBPS,
      _assetClassIndex,
      _marketIndex
    );
  }

  function reloadConfig() external nonReentrant onlyOwner {
    calculator = Calculator(ConfigStorage(configStorage).calculator());
  }

  function _updateFeeStates(
    address _subAccount,
    PerpStorage.Position memory _position,
    uint256 _sizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) internal returns (uint256 _tradingFee, uint256 _borrowingFee, int256 _fundingFee) {
    // Calculate the trading fee
    _tradingFee = (_sizeDelta * _positionFeeBPS) / BPS;
    emit LogSettleTradingFeeValue(_subAccount, _tradingFee);

    // Calculate the borrowing fee
    _borrowingFee = calculator.getBorrowingFee(
      _assetClassIndex,
      _position.reserveValueE30,
      _position.entryBorrowingRate
    );
    // Update global state
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFee);
    emit LogSettleBorrowingFeeValue(_subAccount, _borrowingFee);

    // Calculate the funding fee
    bool _isLong = _position.positionSizeE30 > 0;
    _fundingFee = calculator.getFundingFee(
      _marketIndex,
      _isLong,
      _position.positionSizeE30,
      _position.entryFundingRate
    );
    // Update global state
    _isLong
      ? _updateAccumFundingLong(_marketIndex, -_fundingFee)
      : _updateAccumFundingShort(_marketIndex, -_fundingFee);
    emit LogSettleFundingFeeValue(_subAccount, uint256(_fundingFee));

    return (_tradingFee, _borrowingFee, _fundingFee);
  }

  function accumSettledBorrowingFee(
    uint256 _assetClassIndex,
    uint256 _borrowingFeeToBeSettled
  ) external nonReentrant onlyWhitelistedExecutor {
    _accumSettledBorrowingFee(_assetClassIndex, _borrowingFeeToBeSettled);
  }

  function _accumSettledBorrowingFee(uint256 _assetClassIndex, uint256 _borrowingFeeToBeSettled) internal {
    PerpStorage _perpStorage = PerpStorage(perpStorage);
    PerpStorage.AssetClass memory _assetClass = _perpStorage.getAssetClassByIndex(uint8(_assetClassIndex));
    _assetClass.sumSettledBorrowingFeeE30 += _borrowingFeeToBeSettled;
    _perpStorage.updateAssetClass(uint8(_assetClassIndex), _assetClass);
  }

  function increaseCollateral(address _subAccount, int256 _unrealizedPnl, int256 _fundingFee) external {
    _increaseCollateral(_subAccount, _unrealizedPnl, _fundingFee);
  }

  function settleTraderProfit(address _subAccount, address _tpToken, int256 _realizedProfitE30) external {
    IncreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    _vars.subAccount = _subAccount;
    // check unrealized pnl
    if (_realizedProfitE30 > 0) {
      _vars.unrealizedPnlToBeReceived = uint256(_realizedProfitE30);
      emit LogReceivedUnRealizedPnlValue(_vars.subAccount, _vars.unrealizedPnlToBeReceived);

      // Pay trader with selected tp token
      {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfigByToken(_tpToken);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;

        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);
        _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);

        // get profit from plp
        _increaseCollateralWithUnrealizedPnlFromPlp(_vars);
      }

      // if tp token can't repayment cover then try repay with other tokens
      if (_vars.unrealizedPnlToBeReceived > 0)
        _increaseCollateral(_subAccount, int256(_vars.unrealizedPnlToBeReceived), 0);
    }
  }

  function _increaseCollateral(address _subAccount, int256 _unrealizedPnl, int256 _fundingFee) internal {
    IncreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());

    _vars.subAccount = _subAccount;
    // check unrealized pnl
    if (_unrealizedPnl > 0) {
      _vars.unrealizedPnlToBeReceived = uint256(_unrealizedPnl);
      emit LogReceivedUnRealizedPnlValue(_vars.subAccount, _vars.unrealizedPnlToBeReceived);
    }
    // check funding fee
    if (_fundingFee < 0) {
      _vars.fundingFeeToBeReceived = uint256(-_fundingFee);
      emit LogReceivedFundingFeeValue(_vars.subAccount, _vars.fundingFeeToBeReceived);
    }

    bytes32[] memory _plpAssetIds = _vars.configStorage.getPlpAssetIds();
    uint256 _len = _plpAssetIds.length;
    {
      // loop for get fee from fee reserve
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_plpAssetIds[i]);
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
      // loop for get fee and profit from plp
      for (uint256 i = 0; i < _len; ) {
        ConfigStorage.AssetConfig memory _assetConfig = _vars.configStorage.getAssetConfig(_plpAssetIds[i]);
        _vars.tokenDecimal = _assetConfig.decimals;
        _vars.token = _assetConfig.tokenAddress;
        (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(_assetConfig.assetId, false);

        _vars.payerBalance = _vars.vaultStorage.plpLiquidity(_assetConfig.tokenAddress);

        // get profit from plp
        _increaseCollateralWithUnrealizedPnlFromPlp(_vars);
        // get fee from plp
        _increaseCollateralWithFundingFeeFromPlp(_vars);

        unchecked {
          ++i;
        }
      }
    }
  }

  function _increaseCollateralWithUnrealizedPnlFromPlp(IncreaseCollateralVars memory _vars) internal {
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
      uint256 _settlementFee = (_repayAmount * _settlementFeeRate) / 1e18;

      // book the balances
      _vars.vaultStorage.payTraderProfit(_vars.subAccount, _vars.token, _repayAmount, _settlementFee);

      // deduct _vars.unrealizedPnlToBeReceived with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.unrealizedPnlToBeReceived -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      emit LogReceivedUnRealizedPnlAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
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
      _vars.payerBalance -= _repayAmount;

      emit LogReceivedFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
    }
  }

  function _increaseCollateralWithFundingFeeFromPlp(IncreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBeReceived > 0) {
      // We are going to deduct plp liquidity balance,
      // so we need to check whether plp has this collateral token or not.
      // If not skip to next token
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.fundingFeeToBeReceived,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // book the balances
      _vars.vaultStorage.borrowFundingFeeFromPlpToTrader(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBeReceived -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      emit LogReceivedFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
    }
  }

  function decreaseCollateral(
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator
  ) external nonReentrant onlyWhitelistedExecutor {
    _decreaseCollateral(
      _subAccount,
      _unrealizedPnl,
      _fundingFee,
      _borrowingFee,
      _tradingFee,
      _liquidationFee,
      _liquidator
    );
  }

  function _decreaseCollateral(
    address _subAccount,
    int256 _unrealizedPnl,
    int256 _fundingFee,
    uint256 _borrowingFee,
    uint256 _tradingFee,
    uint256 _liquidationFee,
    address _liquidator
  ) internal {
    DecreaseCollateralVars memory _vars;

    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    _vars.subAccount = _subAccount;

    address[] memory _collateralTokens = _vars.vaultStorage.getTraderTokens(_vars.subAccount);
    uint256 _len = _collateralTokens.length;
    // check loss
    if (_unrealizedPnl < 0) {
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
      _vars.vaultStorage.addFundingFeeDebt(_subAccount, uint256(_fundingFee));
    }
    _vars.fundingFeeToBePaid = _vars.vaultStorage.fundingFeeDebt(_subAccount);

    // check liquidation fee
    _vars.liquidationFeeToBePaid = _liquidationFee;

    emit LogSettleUnRealizedPnlValue(_vars.subAccount, _vars.unrealizedPnlToBePaid);
    emit LogSettleTradingFeeValue(_vars.subAccount, _vars.tradingFeeToBePaid);
    emit LogSettleBorrowingFeeValue(_vars.subAccount, _vars.borrowingFeeToBePaid);
    emit LogSettleFundingFeeValue(_vars.subAccount, _vars.fundingFeeToBePaid);
    emit LogSettleLiquidationFeeValue(_vars.subAccount, _vars.liquidationFeeToBePaid);

    // loop for settle
    for (uint256 i = 0; i < _len; ) {
      _vars.token = _collateralTokens[i];
      _vars.tokenDecimal = _vars.configStorage.getAssetTokenDecimal(_vars.token);
      (_vars.tokenPrice, ) = _vars.oracle.getLatestPrice(
        ConfigStorage(_vars.configStorage).tokenAssetIds(_vars.token),
        false
      );

      _vars.payerBalance = _vars.vaultStorage.traderBalances(_vars.subAccount, _vars.token);
      _vars.plpDebt = _vars.vaultStorage.plpLiquidityDebtUSDE30();
      // settle liquidation fee
      _decreaseCollateralWithLiquidationFee(_vars, _liquidator);
      // settle borrowing fee
      _decreaseCollateralWithBorrowingFeeToPlp(_vars);
      // settle trading fee
      _decreaseCollateralWithTradingFeeToProtocolFee(_vars);
      // settle funding fee to plp
      _decreaseCollateralWithFundingFeeToPlp(_vars);
      // settle funding fee to fee reserve
      _decreaseCollateralWithFundingFeeToFeeReserve(_vars);
      // settle loss fee
      _decreaseCollateralWithUnrealizedPnlToPlp(_vars);

      unchecked {
        ++i;
      }
    }
  }

  function _decreaseCollateralWithUnrealizedPnlToPlp(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.unrealizedPnlToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.unrealizedPnlToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      VaultStorage(_vars.vaultStorage).payPlp(_vars.subAccount, _vars.token, _repayAmount);

      _vars.unrealizedPnlToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subLossDebt(_vars.subAccount, _repayValue);

      emit LogSettleUnRealizedPnlAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
    }
  }

  function _decreaseCollateralWithFundingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    // If absFundingFeeToBePaid is less than borrowing debts from PLP, Then Trader repay with all current collateral amounts to PLP
    // Else Trader repay with just enough current collateral amounts to PLP
    if (_vars.payerBalance > 0 && _vars.fundingFeeToBePaid > 0 && _vars.plpDebt > 0) {
      // Trader repay with just enough current collateral amounts to PLP
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.plpDebt,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // book the balances
      _vars.vaultStorage.repayFundingFeeDebtFromTraderToPlp(_vars.subAccount, _vars.token, _repayAmount, _repayValue);

      // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.fundingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subFundingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
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

      emit LogSettleFundingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
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

      emit LogSettleTradingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _devFeeAmount, _protocolFeeAmount);
    }
  }

  function _decreaseCollateralWithBorrowingFeeToPlp(DecreaseCollateralVars memory _vars) internal {
    if (_vars.payerBalance > 0 && _vars.borrowingFeeToBePaid > 0) {
      (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
        _vars.payerBalance,
        _vars.borrowingFeeToBePaid,
        _vars.tokenPrice,
        _vars.tokenDecimal
      );
      // devFee = tradingFee * devFeeRate
      uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
      // the rest after dev fee deduction belongs to plp liquidity
      uint256 _plpFeeAmount = _repayAmount - _devFeeAmount;

      // book those moving balances
      _vars.vaultStorage.payBorrowingFee(_vars.subAccount, _vars.token, _devFeeAmount, _plpFeeAmount);

      // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
      _vars.borrowingFeeToBePaid -= _repayValue;
      _vars.payerBalance -= _repayAmount;

      _vars.vaultStorage.subBorrowingFeeDebt(_vars.subAccount, _repayValue);

      emit LogSettleBorrowingFeeAmount(_vars.subAccount, _vars.token, _repayValue, _devFeeAmount, _plpFeeAmount);
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

      emit LogSettleLiquidationFeeAmount(_vars.subAccount, _vars.token, _repayValue, _repayAmount);
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

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
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
}
