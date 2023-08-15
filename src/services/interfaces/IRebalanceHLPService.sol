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

  /// @param token: the address of ERC20 token that will be converted into GLP.
  /// @param tokenMed: Medium token for swapping, in case of swap before rebalance.
  ///                  Set address(0) if swap is no need.
  /// @param amount: the amount of token to convert to GLP.
  /// @param minAmountOutUSD: the minimum acceptable USD value of the GLP purchased
  /// @param minAmountOutGlp: the minimum acceptable GLP amount
  struct AddGlpParams {
    address token;
    address tokenMed;
    uint256 amount;
    uint256 minAmountOutUSD;
    uint256 minAmountOutGlp;
  }

  struct WithdrawGlpParams {
    address token;
    uint256 glpAmount;
    uint256 minOut;
  }

  struct WithdrawGlpResult {
    address token;
    uint256 amount;
  }

  // execute reinvesting
  function addGlp(AddGlpParams[] calldata params) external returns (uint256 receivedGlp);

  function withdrawGlp(WithdrawGlpParams[] calldata params) external returns (WithdrawGlpResult[] memory result);

  // Setter
  function setMinHLPValueLossBPS(uint16 minTvlBPS) external;

  // Getters
  function sglp() external view returns (IERC20Upgradeable);

  function vaultStorage() external view returns (IVaultStorage);

  function rewardRouter() external view returns (IGmxRewardRouterV2);

  function glpManager() external view returns (IGmxGlpManager);

  function calculator() external view returns (ICalculator);

  function configStorage() external view returns (IConfigStorage);

  function minHLPValueLossBPS() external view returns (uint16);
}
