// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

interface IRebalanceHLPService {
  error RebalanceHLPService_InvalidTokenAddress();
  error RebalanceHLPService_InvalidTokenAmount();
  error RebalanceHLPService_HlpTvlDropExceedMin();
  error RebalanceHLPService_AmountIsZero();
  error RebalanceHLPService_Slippage();
  error RebalanceHLPService_InvalidPath();
  error RebalanceHLPService_OneInchSwapFailed();

  struct SwapParams {
    uint256 amountIn;
    uint256 minAmountOut;
    address[] path;
  }

  struct WithdrawGlpResult {
    address token;
    uint256 amount;
  }

  function swap(SwapParams calldata params) external returns (uint256 amountOut);

  function oneInchSwap(SwapParams calldata params, bytes calldata oneInchData) external returns (uint256 amountOut);

  // Setter
  function setMinHLPValueLossBPS(uint16 minTvlBPS) external;

  // Getters
  function vaultStorage() external view returns (IVaultStorage);

  function calculator() external view returns (ICalculator);

  function configStorage() external view returns (IConfigStorage);

  function minHLPValueLossBPS() external view returns (uint16);
}
