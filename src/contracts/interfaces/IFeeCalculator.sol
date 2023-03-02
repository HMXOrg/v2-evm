// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IFeeCalculator {
  /**
   * Errors
   */
  error IFeeCalculator_InvalidAddress();

  /**
   * Structs
   */

  struct SettleMarginFeeVar {
    int256 feeUsd;
    uint256 absFeeUsd;
    address[] plpUnderlyingTokens;
  }

  struct SettleMarginFeeLoopVar {
    address underlyingToken;
    uint256 underlyingTokenDecimal;
    uint256 traderBalance;
    uint256 traderBalanceValue;
    uint256 price;
    uint256 feeTokenAmount;
    uint256 repayFeeTokenAmount;
    uint256 devFeeTokenAmount;
  }

  struct SettleFundingFeeVar {
    int256 feeUsd;
    uint256 absFeeUsd;
    uint256 plpLiquidityDebtUSDE30;
    address[] plpUnderlyingTokens;
  }

  struct SettleFundingFeeLoopVar {
    address underlyingToken;
    uint256 underlyingTokenDecimal;
    uint256 traderBalance;
    uint256 traderBalanceValue;
    uint256 fundingFee;
    uint256 fundingFeeValue;
    uint256 price;
    uint256 feeTokenAmount;
    uint256 feeTokenValue;
    uint256 repayFeeTokenAmount;
  }

  /**
   * Functions
   */

  function payFundingFee(
    address subAccount,
    uint256 absFeeUsd,
    SettleFundingFeeLoopVar memory tmpVars
  ) external returns (uint256 newAbsFeeUsd);

  function receiveFundingFee(
    address subAccount,
    uint256 absFeeUsd,
    SettleFundingFeeLoopVar memory tmpVars
  ) external returns (uint256 newAbsFeeUsd);

  function borrowFundingFeeFromPLP(
    address subAccount,
    address _oracle,
    address[] memory plpUnderlyingTokens,
    uint256 absFeeUsd
  ) external returns (uint256 newAbsFeeUsd);

  function repayFundingFeeDebtToPLP(
    address subAccount,
    uint256 absFeeUsd,
    uint256 plpLiquidityDebtUSDE30,
    SettleFundingFeeLoopVar memory tmpVars
  ) external returns (uint256 newAbsFeeUsd);
}
