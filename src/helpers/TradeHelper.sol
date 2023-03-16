// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";

import { FeeCalculator } from "@hmx/contracts/FeeCalculator.sol";

import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

contract TradeHelper is ITradeHelper {
  uint32 internal constant BPS = 1e4;

  event LogCollectTradingFee(address account, uint8 assetClass, uint256 feeUsd);

  event LogCollectBorrowingFee(address account, uint8 assetClass, uint256 feeUsd);

  event LogCollectFundingFee(address account, uint8 assetClass, int256 feeUsd);

  event LogSettleTradingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleTradingFeeAmount(address subAccount, address token, uint256 devFeeAmount, uint256 protocolFeeAmount);

  event LogSettleBorrowingFeeValue(address subAccount, uint256 feeUsd);
  event LogSettleBorrowingFeeAmount(address subAccount, address token, uint256 devFeeAmount, uint256 plpFeeAmount);

  event LogSettleFundingFeeValue(address subAccount, int256 feeUsd);
  // event LogSettleFundingFeeAmount(address subAccount, address token, uint256 devFeeAmount, uint256 plpFeeAmount);

  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  Calculator public calculator; // cache this from configStorage

  constructor(address _perpStorage, address _vaultStorage, address _configStorage) {
    // Sanity check
    // PerpStorage(_perpStorage).getGlobalState();
    // VaultStorage(_vaultStorage).plpLiquidityDebtUSDE30();
    // ConfigStorage(_configStorage).getLiquidityConfig();

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

  /// @notice This function updates the borrowing rate for the given asset class index.
  /// @param _assetClassIndex The index of the asset class.
  /// @param _limitPriceE30 Price to be overwritten to a specified asset
  /// @param _limitAssetId Asset to be overwritten by _limitPriceE30
  function updateBorrowingRate(uint8 _assetClassIndex, uint256 _limitPriceE30, bytes32 _limitAssetId) external {
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
  function updateFundingRate(uint256 _marketIndex, uint256 _limitPriceE30) external {
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
      (int256 newFundingRate, int256 nextFundingRateLong, int256 nextFundingRateShort) = calculator.getNextFundingRate(
        _marketIndex,
        _limitPriceE30
      );

      _globalMarket.currentFundingRate = newFundingRate;
      _globalMarket.accumFundingLong += nextFundingRateLong;
      _globalMarket.accumFundingShort += nextFundingRateShort;
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
  ) external {
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
  ) external {
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
  function settleMarginFee(address _subAccount) external {
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
  function settleFundingFee(address _subAccount, uint256 _limitPriceE30, bytes32 _limitAssetId) external {
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
          if (tmpVars.traderBalance != 0 && acmVars.absFeeUsd > 0)
            acmVars.absFeeUsd = _feeCalculator.payFundingFee(_subAccount, acmVars.absFeeUsd, tmpVars);
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

  struct SettleTradingFeeVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    uint256 tradingFeeToBePaid;
    address[] collateralTokens;
    uint256 collateralTokensLength;
    ConfigStorage.TradingConfig tradingConfig;
  }

  function _settleTradingFee(address _subAccount, uint256 _absSizeDelta, uint32 _positionFeeBPS) internal {
    SettleTradingFeeVars memory _vars;
    // SLOAD
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.collateralTokens = _vars.configStorage.getCollateralTokens();
    _vars.collateralTokensLength = _vars.collateralTokens.length;
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    // Calculate trading Fee USD
    _vars.tradingFeeToBePaid = (_absSizeDelta * _positionFeeBPS) / BPS;

    emit LogSettleTradingFeeValue(_subAccount, _vars.tradingFeeToBePaid);

    // We are now trying our best to pay `_vars.tradingFeeToBePaid` by deducting balance from the trader collateral.
    // If one collateral cannot cover, try the next one and so on.
    // If all of the collaterals still cannot cover, revert.
    for (uint256 i; i < _vars.collateralTokensLength; ) {
      // Get trader balance of each collateral
      uint256 _traderBalance = _vars.vaultStorage.traderBalances(_subAccount, _vars.collateralTokens[i]);

      // if trader has some of this collateral token, try cover the fee with it
      if (_traderBalance > 0) {
        // protocol fee portion + dev fee portion
        (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
          _vars.configStorage,
          _vars.oracle,
          _traderBalance,
          _vars.tradingFeeToBePaid,
          _vars.collateralTokens[i]
        );

        // devFee = tradingFee * devFeeRate
        uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
        // the rest after dev fee deduction belongs to protocol fee portion
        uint256 _protocolFeeAmount = _repayAmount - _devFeeAmount;

        // book those moving balances
        _vars.vaultStorage.payTradingFee(_subAccount, _vars.collateralTokens[i], _devFeeAmount, _protocolFeeAmount);

        // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
        _vars.tradingFeeToBePaid -= _repayValue;

        emit LogSettleTradingFeeAmount(_subAccount, _vars.collateralTokens[i], _devFeeAmount, _protocolFeeAmount);
      }
      // else continue, as trader does not have any of this collateral token

      // stop iteration, if all fees are covered
      if (_vars.tradingFeeToBePaid == 0) break;

      unchecked {
        ++i;
      }
    }

    // If fee cannot be covered, revert.
    if (_vars.tradingFeeToBePaid > 0) revert ITradeHelper_TradingFeeCannotBeCovered();
  }

  struct SettleBorrowingFeeVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    uint256 borrowingFeeToBePaid;
    address[] collateralTokens;
    uint256 collateralTokensLength;
    ConfigStorage.TradingConfig tradingConfig;
  }

  function _settleBorrowingFee(
    address _subAccount,
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate
  ) internal {
    SettleBorrowingFeeVars memory _vars;
    // SLOAD
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.collateralTokens = _vars.configStorage.getCollateralTokens();
    _vars.collateralTokensLength = _vars.collateralTokens.length;
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    // Calculate the borrowing fee
    _vars.borrowingFeeToBePaid = calculator.getBorrowingFee(_assetClassIndex, _reservedValue, _entryBorrowingRate);

    emit LogSettleBorrowingFeeValue(_subAccount, _vars.borrowingFeeToBePaid);

    // We are now trying our best to pay `_vars.borrowingFeeToBePaid` by deducting balance from the trader collateral.
    // If one collateral cannot cover, try the next one and so on.
    // If all of the collaterals still cannot cover, revert.
    for (uint256 i; i < _vars.collateralTokensLength; ) {
      // Get trader balance of each collateral
      uint256 _traderBalance = _vars.vaultStorage.traderBalances(_subAccount, _vars.collateralTokens[i]);

      // if trader has some of this collateral token, try cover the fee with it
      if (_traderBalance > 0) {
        // plp fee portion + dev fee portion
        (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
          _vars.configStorage,
          _vars.oracle,
          _traderBalance,
          _vars.borrowingFeeToBePaid,
          _vars.collateralTokens[i]
        );

        // devFee = tradingFee * devFeeRate
        uint256 _devFeeAmount = (_repayAmount * _vars.tradingConfig.devFeeRateBPS) / BPS;
        // the rest after dev fee deduction belongs to plp liquidity
        uint256 _plpFeeAmount = _repayAmount - _devFeeAmount;

        // book those moving balances
        _vars.vaultStorage.payBorrowingFee(_subAccount, _vars.collateralTokens[i], _devFeeAmount, _plpFeeAmount);

        // deduct _vars.tradingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
        _vars.borrowingFeeToBePaid -= _repayValue;

        emit LogSettleBorrowingFeeAmount(_subAccount, _vars.collateralTokens[i], _devFeeAmount, _plpFeeAmount);
      }
      // else continue, as trader does not have any of this collateral token

      // stop iteration, if all fees are covered
      if (_vars.borrowingFeeToBePaid == 0) break;

      unchecked {
        ++i;
      }
    }

    // If fee cannot be covered, revert.
    if (_vars.borrowingFeeToBePaid > 0) revert ITradeHelper_BorrowingFeeCannotBeCovered();
  }

  struct SettleFundingFeeVars {
    VaultStorage vaultStorage;
    ConfigStorage configStorage;
    OracleMiddleware oracle;
    int256 fundingFeeToBePaid;
    uint256 absFundingFeeToBePaid;
    address[] collateralTokens;
    uint256 collateralTokensLength;
    ConfigStorage.TradingConfig tradingConfig;
    bool isLong;
    bool traderMustPay;
  }

  function _settleFundingFee(
    address _subAccount,
    uint256 _marketIndex,
    int256 _positionSizeE30,
    int256 _entryFundingRate
  ) internal {
    SettleFundingFeeVars memory _vars;
    // SLOAD
    _vars.vaultStorage = VaultStorage(vaultStorage);
    _vars.configStorage = ConfigStorage(configStorage);
    _vars.oracle = OracleMiddleware(_vars.configStorage.oracle());
    _vars.collateralTokens = _vars.configStorage.getCollateralTokens();
    _vars.collateralTokensLength = _vars.collateralTokens.length;
    _vars.tradingConfig = _vars.configStorage.getTradingConfig();

    // Calculate the funding fee
    _vars.isLong = _positionSizeE30 > 0;
    _vars.fundingFeeToBePaid = calculator.getFundingFee(
      _marketIndex,
      _vars.isLong,
      _positionSizeE30,
      _entryFundingRate
    );
    _vars.absFundingFeeToBePaid = _abs(_vars.fundingFeeToBePaid);

    // Position Exposure   | Funding Fee + | Fund Flow
    // (isLong)            | (fee > 0)     | (traderMustPay)
    // ---------------------------------------------------------------------
    // true                | true          | false  (fee reserve -> trader)
    // true                | false         | true   (trader -> fee reserve)
    // false               | true          | true   (trader -> fee reserve)
    // false               | false         | false  (fee reserve -> trader)

    // Basicly, this is !xor
    _vars.traderMustPay = (_vars.isLong != _vars.fundingFeeToBePaid > 0);

    emit LogSettleFundingFeeValue(_subAccount, _vars.fundingFeeToBePaid);

    // if no funding fee at all, just exit to save gas
    if (_vars.fundingFeeToBePaid == 0) return;

    // We are now trying our best to cover `_vars.absFundingFeeToBePaid`.
    // If one collateral cannot cover, try the next one and so on.
    // If all of the collaterals still cannot cover, revert.
    for (uint256 i; i < _vars.collateralTokensLength; ) {
      if (_vars.traderMustPay) {
        // When trader is the payer
        uint256 _traderBalance = _vars.vaultStorage.traderBalances(_subAccount, _vars.collateralTokens[i]);

        // We are going to deduct trader balance,
        // so we need to check whether trader has this collateral token or not.
        // If not skip to next token
        if (_traderBalance > 0) {
          (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
            _vars.configStorage,
            _vars.oracle,
            _traderBalance,
            _vars.absFundingFeeToBePaid,
            _vars.collateralTokens[i]
          );

          // book the balances
          _vars.vaultStorage.payFundingFeeFromTraderToPlp(_subAccount, _vars.collateralTokens[i], _repayAmount);

          // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
          _vars.absFundingFeeToBePaid -= _repayValue;
        }
      } else {
        // When plp liquidity is the payer
        uint256 _plpBalance = _vars.vaultStorage.plpLiquidity(_vars.collateralTokens[i]);

        // We are going to deduct plp liquidity balance,
        // so we need to check whether plp has this collateral token or not.
        // If not skip to next token
        if (_plpBalance > 0) {
          (uint256 _repayAmount, uint256 _repayValue) = _getRepayAmount(
            _vars.configStorage,
            _vars.oracle,
            _plpBalance,
            _vars.absFundingFeeToBePaid,
            _vars.collateralTokens[i]
          );

          // book the balances
          _vars.vaultStorage.payFundingFeeFromPlpToTrader(_subAccount, _vars.collateralTokens[i], _repayAmount);

          // deduct _vars.absFundingFeeToBePaid with _repayAmount, so that the next iteration could continue deducting the fee
          _vars.absFundingFeeToBePaid -= _repayValue;
        }
      }

      // stop iteration, if all fees are covered
      if (_vars.absFundingFeeToBePaid == 0) break;

      unchecked {
        ++i;
      }
    }

    // If fee cannot be covered, revert.
    if (_vars.absFundingFeeToBePaid > 0) revert ITradeHelper_FundingFeeCannotBeCovered();
  }

  function settleAllFees(
    PerpStorage.Position memory _position,
    uint256 _absSizeDelta,
    uint32 _positionFeeBPS,
    uint8 _assetClassIndex,
    uint256 _marketIndex
  ) external {
    address _subAccount = _getSubAccount(_position.primaryAccount, _position.subAccountId);
    _settleTradingFee(_subAccount, _absSizeDelta, _positionFeeBPS);
    _settleBorrowingFee(_subAccount, _assetClassIndex, _position.reserveValueE30, _position.entryBorrowingRate);
    _settleFundingFee(_subAccount, _marketIndex, _position.positionSizeE30, _position.entryFundingRate);
  }

  // function _valueToTokenAmount(
  //   ConfigStorage _configStorage,
  //   OracleMiddleware _oracle,
  //   uint256 _valueE30,
  //   address _token
  // ) internal view returns (uint256) {
  //   bytes32 _tokenAssetId = _configStorage.tokenAssetIds(_token);
  //   uint8 _tokenDecimal = _configStorage.getAssetTokenDecimal(_token);
  //   (uint256 _tokenPrice, ) = _oracle.getLatestPrice(_tokenAssetId, false);

  //   return (_valueE30 * (10 ** _tokenDecimal)) / _tokenPrice;
  // }

  function _getRepayAmount(
    ConfigStorage _configStorage,
    OracleMiddleware _oracle,
    uint256 _traderBalance,
    uint256 _feeValueE30,
    address _token
  ) internal view returns (uint256 _repayAmount, uint256 _repayValueE30) {
    bytes32 _tokenAssetId = _configStorage.tokenAssetIds(_token);
    uint8 _tokenDecimal = _configStorage.getAssetTokenDecimal(_token);
    (uint256 _tokenPrice, ) = _oracle.getLatestPrice(_tokenAssetId, false);

    uint256 _feeAmount = (_feeValueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_traderBalance > _feeAmount) {
      // _traderBalance can cover the rest of the fee
      return (_feeAmount, _feeValueE30);
    } else {
      // _traderBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _traderBalanceValue = (_traderBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_traderBalance, _traderBalanceValue);
    }
  }

  function _abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function _getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }
}
