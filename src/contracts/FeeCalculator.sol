// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { AddressUtils } from "../libraries/AddressUtils.sol";

import { IFeeCalculator } from "./interfaces/IFeeCalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";

contract FeeCalculator is IFeeCalculator {
  // using libs for type
  using AddressUtils for address;

  /**
   * States
   */
  address public vaultStorage;
  address public configStorage;

  constructor(address _vaultStorage, address _configStorage) {
    if (_vaultStorage == address(0) || _configStorage == address(0)) revert IFeeCalculator_InvalidAddress();

    vaultStorage = _vaultStorage;
    configStorage = _configStorage;

    // Sanity check
    IVaultStorage(vaultStorage).plpLiquidityDebtUSDE30();
    IConfigStorage(configStorage).calculator();
  }

  /// @notice Trader pay funding fee to Vault.
  /// @param _subAccount Address of the trader's sub-account to repay the fee.
  /// @param _absFeeUsd Value of the fee in USD for the trader's sub-account.
  /// @param _tmpVars Temporary struct variable used for calculation.
  /// @return _newAbsFeeUsd Value of the remaining fee in USD for the trader's sub-account after repayment.
  function payFundingFee(
    address _subAccount,
    uint256 _absFeeUsd,
    SettleFundingFeeLoopVar memory _tmpVars
  ) external returns (uint256 _newAbsFeeUsd) {
    // Calculate the fee amount in the plp underlying token
    _tmpVars.feeTokenAmount = (_absFeeUsd * (10 ** _tmpVars.underlyingTokenDecimal)) / _tmpVars.price; // @todo - validate zero price

    // Repay the fee amount and subtract it from the balance
    _tmpVars.repayFeeTokenAmount = 0;

    if (_tmpVars.traderBalance > _tmpVars.feeTokenAmount) {
      _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount;
      _tmpVars.traderBalance -= _tmpVars.feeTokenAmount;
      _absFeeUsd = 0;
    } else {
      // Calculate the balance value of the plp underlying token in USD
      _tmpVars.traderBalanceValue = (_tmpVars.traderBalance * _tmpVars.price) / (10 ** _tmpVars.underlyingTokenDecimal);

      _tmpVars.repayFeeTokenAmount = _tmpVars.traderBalance;
      _tmpVars.traderBalance = 0;
      _absFeeUsd -= _tmpVars.traderBalanceValue;
    }

    IVaultStorage(vaultStorage).collectFundingFee(
      _subAccount,
      _tmpVars.underlyingToken,
      _tmpVars.repayFeeTokenAmount,
      _tmpVars.traderBalance
    );

    return _absFeeUsd;
  }

  /// @notice Trader receive funding fee from Vault.
  /// @param _subAccount Address of the trader's sub-account to repay the fee.
  /// @param _absFeeUsd Value of the fee in USD for the trader's sub-account.
  /// @param _tmpVars Temporary struct variable used for calculation.
  /// @return _newAbsFeeUsd Value of the remaining fee in USD for the trader's sub-account after repayment.
  function receiveFundingFee(
    address _subAccount,
    uint256 _absFeeUsd,
    SettleFundingFeeLoopVar memory _tmpVars
  ) external returns (uint256 _newAbsFeeUsd) {
    // Calculate the fee amount in the plp underlying token
    _tmpVars.feeTokenAmount = (_absFeeUsd * (10 ** _tmpVars.underlyingTokenDecimal)) / _tmpVars.price;

    if (_tmpVars.fundingFee > _tmpVars.feeTokenAmount) {
      // funding fee token has enough amount to repay fee to trader
      _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount;
      _tmpVars.traderBalance += _tmpVars.feeTokenAmount;
      _absFeeUsd = 0;
    } else {
      // funding fee token has not enough amount to repay fee to trader
      // Calculate the funding Fee value of the plp underlying token in USD
      _tmpVars.fundingFeeValue = (_tmpVars.fundingFee * _tmpVars.price) / (10 ** _tmpVars.underlyingTokenDecimal);

      _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount;
      _tmpVars.traderBalance += _tmpVars.feeTokenAmount;
      _absFeeUsd -= _tmpVars.fundingFeeValue;
    }

    IVaultStorage(vaultStorage).repayFundingFee(
      _subAccount,
      _tmpVars.underlyingToken,
      _tmpVars.repayFeeTokenAmount,
      _tmpVars.traderBalance
    );

    return _absFeeUsd;
  }

  /// @notice Allows a trader to borrow the funding fee from the Perpetual Liquidity Provider (PLP) and pay it to the vault.
  /// @param _subAccount Address of the trader's sub-account to repay the fee.
  /// @param _oracle Address of the oracle contract used for price feed.
  /// @param _plpUnderlyingTokens Array of addresses of the PLP's underlying tokens.
  /// @param _absFeeUsd Value of the fee in USD for the trader's sub-account.
  /// @return _newAbsFeeUsd Value of the remaining fee in USD for the trader's sub-account after repayment.
  function borrowFundingFeeFromPLP(
    address _subAccount,
    address _oracle,
    address[] memory _plpUnderlyingTokens,
    uint256 _absFeeUsd
  ) external returns (uint256 _newAbsFeeUsd) {
    IVaultStorage _vaultStorage = IVaultStorage(vaultStorage);
    IConfigStorage _configStorage = IConfigStorage(configStorage);

    // Loop through all the plp underlying tokens for the sub-account
    for (uint256 i = 0; i < _plpUnderlyingTokens.length; ) {
      SettleFundingFeeLoopVar memory _tmpVars;
      _tmpVars.underlyingToken = _plpUnderlyingTokens[i];

      //find decimals
      bytes32 _assetId = _configStorage.tokenAssetIds(_tmpVars.underlyingToken);
      _tmpVars.underlyingTokenDecimal = _configStorage.getAssetPlpTokenConfigs(_assetId).decimals;
      uint256 plpLiquidityAmount = _vaultStorage.plpLiquidity(_tmpVars.underlyingToken);

      // Retrieve the latest price and confident threshold of the plp underlying token
      (_tmpVars.price, ) = IOracleMiddleware(_oracle).getLatestPrice(
        _tmpVars.underlyingToken.toBytes32(),
        false,
        _configStorage.getMarketConfigByToken(_tmpVars.underlyingToken).priceConfidentThreshold,
        30
      );

      // Calculate the fee amount in the plp underlying token
      _tmpVars.feeTokenAmount = (_absFeeUsd * (10 ** _tmpVars.underlyingTokenDecimal)) / _tmpVars.price;

      uint256 borrowPlpLiquidityValue;
      if (plpLiquidityAmount > _tmpVars.feeTokenAmount) {
        // plp underlying token has enough amount to repay fee to trader
        borrowPlpLiquidityValue = _absFeeUsd;
        _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount;
        _tmpVars.traderBalance += _tmpVars.feeTokenAmount;

        _absFeeUsd = 0;
      } else {
        // plp underlying token has not enough amount to repay fee to trader
        // Calculate the plpLiquidityAmount value of the plp underlying token in USD
        borrowPlpLiquidityValue = (plpLiquidityAmount * _tmpVars.price) / (10 ** _tmpVars.underlyingTokenDecimal);
        _tmpVars.repayFeeTokenAmount = plpLiquidityAmount;
        _tmpVars.traderBalance += plpLiquidityAmount;
        _absFeeUsd -= borrowPlpLiquidityValue;
      }

      _vaultStorage.borrowFundingFeeFromPLP(
        _subAccount,
        _tmpVars.underlyingToken,
        _tmpVars.repayFeeTokenAmount,
        borrowPlpLiquidityValue,
        _tmpVars.traderBalance
      );

      if (_absFeeUsd == 0) {
        break;
      }

      {
        unchecked {
          ++i;
        }
      }
    }

    return _absFeeUsd;
  }

  /// @notice Repay funding fee to PLP
  /// @param _subAccount - Trader's sub-account to repay fee
  /// @param _absFeeUsd - Fee value of trader's sub-account
  /// @param _plpLiquidityDebtUSDE30 - Debt value from PLP
  /// @param _tmpVars - Temporary struct variable
  function repayFundingFeeDebtToPLP(
    address _subAccount,
    uint256 _absFeeUsd,
    uint256 _plpLiquidityDebtUSDE30,
    SettleFundingFeeLoopVar memory _tmpVars
  ) external returns (uint256 _newAbsFeeUsd) {
    // Calculate the sub-account's fee debt to token amounts
    _tmpVars.feeTokenAmount = (_absFeeUsd * (10 ** _tmpVars.underlyingTokenDecimal)) / _tmpVars.price;

    // Calculate the debt in USD to plp underlying token amounts
    uint256 plpLiquidityDebtAmount = (_plpLiquidityDebtUSDE30 * (10 ** _tmpVars.underlyingTokenDecimal)) /
      _tmpVars.price;
    uint256 traderBalanceValueE30 = (_tmpVars.traderBalance * _tmpVars.price) / (10 ** _tmpVars.underlyingTokenDecimal);

    if (_tmpVars.feeTokenAmount >= plpLiquidityDebtAmount) {
      // If margin fee to repay is grater than debt on PLP (Rare case)
      if (_tmpVars.traderBalance > _tmpVars.feeTokenAmount) {
        // If trader has enough token amounts to repay fee to PLP
        _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount; // Amount of feeTokenAmount that PLP will receive
        _tmpVars.traderBalance -= _tmpVars.feeTokenAmount; // Deducts all feeTokenAmount to repay to PLP
        _tmpVars.feeTokenValue = _plpLiquidityDebtUSDE30; // USD value of feeTokenAmount that PLP will receive
        _absFeeUsd -= _plpLiquidityDebtUSDE30; // Deducts margin fee on trader's sub-account
      } else {
        _tmpVars.repayFeeTokenAmount = _tmpVars.traderBalance; // Amount of feeTokenAmount that PLP will receive
        _tmpVars.traderBalance = 0; // Deducts all feeTokenAmount to repay to PLP
        _tmpVars.feeTokenValue = _plpLiquidityDebtUSDE30; // USD value of feeTokenAmount that PLP will receive
        _absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      }
    } else if (_tmpVars.feeTokenAmount < plpLiquidityDebtAmount) {
      if (_tmpVars.traderBalance >= _tmpVars.feeTokenAmount) {
        traderBalanceValueE30 =
          ((_tmpVars.traderBalance - _tmpVars.feeTokenAmount) * _tmpVars.price) /
          (10 ** _tmpVars.underlyingTokenDecimal);

        _tmpVars.repayFeeTokenAmount = _tmpVars.feeTokenAmount; // Trader will repay fee with this token amounts they have
        _tmpVars.traderBalance -= _tmpVars.feeTokenAmount; // Deducts repay token amounts from trader account
        _tmpVars.feeTokenValue = traderBalanceValueE30; // USD value of token amounts that PLP will receive
        _absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      } else {
        _tmpVars.repayFeeTokenAmount = _tmpVars.traderBalance; // Trader will repay fee with this token amounts they have
        _tmpVars.traderBalance = 0; // Deducts repay token amounts from trader account
        _tmpVars.feeTokenValue = traderBalanceValueE30; // USD value of token amounts that PLP will receive
        _absFeeUsd -= traderBalanceValueE30; // Deducts margin fee on trader's sub-account
      }

      return _absFeeUsd;
    }

    IVaultStorage(vaultStorage).repayFundingFeeToPLP(
      _subAccount,
      _tmpVars.underlyingToken,
      _tmpVars.repayFeeTokenAmount,
      _tmpVars.feeTokenValue,
      _tmpVars.traderBalance
    );
  }
}
