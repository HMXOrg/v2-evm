// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxV2ExchangeRouter {
  function sendWnt(address receiver, uint256 amount) external payable;

  function sendTokens(address token, address receiver, uint256 amount) external payable;

  /// @dev CreateDepositParams struct used in createDeposit to avoid stack too deep.
  /// @param receiver the address to send the market tokens to
  /// @param callbackContract the callback contract
  /// @param uiFeeReceiver the ui fee receiver
  /// @param market the market to deposit into
  /// @param minMarketTokens the minimum acceptable number of liquidity tokens
  /// @param shouldUnwrapNativeToken whether to unwrap the native token when
  /// sending funds back to the user in case the deposit gets cancelled
  /// @param executionFee the execution fee for keepers
  /// @param callbackGasLimit the gas limit for the callbackContract
  struct CreateDepositParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address initialLongToken;
    address initialShortToken;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minMarketTokens;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }

  function createDeposit(CreateDepositParams calldata params) external returns (bytes32);

  /// @dev CreateWithdrawalParams struct used in createWithdrawal to avoid stack too deep.
  /// @param receiver The address that will receive the withdrawal tokens.
  /// @param callbackContract The contract that will be called back.
  /// @param market The market on which the withdrawal will be executed.
  /// @param minLongTokenAmount The minimum amount of long tokens that must be withdrawn.
  /// @param minShortTokenAmount The minimum amount of short tokens that must be withdrawn.
  /// @param shouldUnwrapNativeToken Whether the native token should be unwrapped when executing the withdrawal.
  /// @param executionFee The execution fee for the withdrawal.
  /// @param callbackGasLimit The gas limit for calling the callback contract.
  struct CreateWithdrawalParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }

  function createWithdrawal(CreateWithdrawalParams calldata params) external returns (bytes32);
}
