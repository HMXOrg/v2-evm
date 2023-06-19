// SPDX-License-Identifier: BUSL-1.1
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
  error LiquidityService_MaxHLPUtilizationExceeded();
  error LiquidityService_InsufficientHLPReserved();
  error LiquidityService_TinyShare();

  /**
   * Enum
   */
  enum LiquidityAction {
    SWAP,
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
  }

  /**
   * States
   */
  function configStorage() external returns (address);

  function vaultStorage() external returns (address);

  function perpStorage() external returns (address);

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
}
