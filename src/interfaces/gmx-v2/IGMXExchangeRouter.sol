// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxExchangeRouter {
  // @dev CreateDepositParams struct used in createDeposit to avoid stack
  // too deep errors
  //
  // @param receiver the address to send the market tokens to
  // @param callbackContract the callback contract
  // @param uiFeeReceiver the ui fee receiver
  // @param market the market to deposit into
  // @param minMarketTokens the minimum acceptable number of liquidity tokens
  // @param shouldUnwrapNativeToken whether to unwrap the native token when
  // sending funds back to the user in case the deposit gets cancelled
  // @param executionFee the execution fee for keepers
  // @param callbackGasLimit the gas limit for the callbackContract
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

  function sendWnt(address receiver, uint256 amount) external payable;

  function sendTokens(address token, address receiver, uint256 amount) external payable;

  function createDeposit(address account, CreateDepositParams calldata params) external returns (bytes32);
}
