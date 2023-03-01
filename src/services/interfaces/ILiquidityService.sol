// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

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
    uint256 _tokenPriceUsd;
    uint256 _amount;
    uint256 _feeRate;
    address _account;
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

  function configStorage() external returns (IConfigStorage);

  function vaultStorage() external returns (IVaultStorage);

  function perpStorage() external returns (IPerpStorage);
}
