// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidityService {
  /**
   * Errors
   */
  error LiquidityService_CircuitBreaker();
  error LiquidityService_InvalidToken();
  error LiquidityService_InvalidInputAmount();
  error LiquidityService_InsufficientLiquidityMint();
  error LiquidityService_BadAmount();
  error LiquidityService_BadAmountOut();
  error LiquidityService_Slippage();

  error LiquidityService_InsufficientLiquidityBuffer();
  error LiquidityService_MaxPLPUtilizationExceeded();
  error LiquidityService_InsufficientPLPReserved();

  /**
   * Struct
   */
  struct CollectFeeRequest {
    address _token;
    address _account;
    uint256 _tokenPriceUsd;
    uint256 _amount;
    uint256 _feeRate;
    LiquidityAction _action;
  }

  /**
   * Enum
   */
  enum LiquidityAction {
    SWAP,
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
  }

  /**
   * Functions
   */
  function addLiquidity(
    address _lpProvider,
    address _token,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256);

  function removeLiquidity(
    address _lpProvider,
    address _tokenOut,
    uint256 _amount,
    uint256 _minAmount
  ) external returns (uint256);

  function configStorage() external returns (address);

  function vaultStorage() external returns (address);

  function perpStorage() external returns (address);
}
