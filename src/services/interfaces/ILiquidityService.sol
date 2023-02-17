// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidityService {
  enum LiquidityAction {
    SWAP,
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
  }

  struct CollectFeeRequest {
    address _token;
    uint256 _tokenPriceUsd;
    uint256 _amount;
    uint256 _feeRate;
    address _account;
    LiquidityAction _action;
  }

  error LiquidityService_CircuitBreaker();
  error LiquidityService_InvalidToken();
  error LiquidityService_InsufficientLiquidityMint();
  error LiquidityService_BadAmount();
  error LiquidityService_BadAmountOut();
  error LiquidityService_Slippage();

  error LiquidityService_InsufficientLiquidityBuffer();
}
