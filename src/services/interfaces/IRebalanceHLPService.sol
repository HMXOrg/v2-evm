// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

interface IRebalanceHLPService {
  // error
  error RebalanceHLPService_OnlyWhitelisted();
  error RebalanceHLPService_AddressIsZero();

  /// @param token: the address of ERC20 token that will be converted into GLP.
  /// @param amount: the amount of token to convert to GLP.
  /// @param minAmountOutUSD: the minimum acceptable USD value of the GLP purchased
  /// @param minAmountOutGlp: the minimum acceptable GLP amount
  struct ExecuteReinvestParams {
    address token;
    uint256 amount;
    uint256 minAmountOutUSD;
    uint256 minAmountOutGlp;
  }

  struct ExecuteWithdrawParams {
    address token;
    uint256 glpAmount;
    uint256 minOut;
  }

  struct WithdrawGLPResult {
    address token;
    uint256 amount;
  }

  // execute reinvesting
  function executReinvestNonHLP(ExecuteReinvestParams[] calldata params) external returns (uint256 receivedGlp);

  function executeWithdrawGLP(
    ExecuteWithdrawParams[] calldata params
  ) external returns (WithdrawGLPResult[] memory result);

  // Setter
  function setWhiteListExecutor(address executor, bool active) external;

  // Get storage
  function sglp() external view returns (IERC20Upgradeable);

  function vaultStorage() external view returns (IVaultStorage);

  function rewardRouter() external view returns (IGmxRewardRouterV2);

  function glpManager() external view returns (IGmxGlpManager);

  function whitelistExecutors(address executor) external view returns (bool);
}
