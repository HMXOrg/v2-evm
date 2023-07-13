// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

interface IRebalanceHLPHandler {
  // error
  error RebalanceHLPHandler_OnlyWhitelisted();
  error RebalanceHLPHandler_ParamsIsEmpty();
  error RebalanceHLPHandler_AddressIsZero();
  error RebalanceHLPHandler_AmountIsZero();
  error RebalanceHLPHandler_InvalidTokenAddress();
  error RebalanceHLPHandler_InvalidTokenAmount();
  error RebalanceHLPHandler_HlpTvlDropExceedMin();

  // execute logic
  function executeLogicReinvestNonHLP(
    IRebalanceHLPService.ExecuteReinvestParams[] calldata params
  ) external returns (uint256 receivedGlp);

  function executeLogicWithdrawGLP(
    IRebalanceHLPService.ExecuteWithdrawParams[] calldata params
  ) external returns (IRebalanceHLPService.WithdrawGLPResult[] memory result);

  // Setter
  function setWhiteListExecutor(address executor, bool active) external;

  function setMinExecutionFee(uint16 minTvlBPS) external;

  function setRebalanceHLPService(address _newService) external;

  // Get storage
  function service() external view returns (IRebalanceHLPService);

  function sglp() external view returns (IERC20Upgradeable);

  function vaultStorage() external view returns (IVaultStorage);

  function calculator() external view returns (ICalculator);

  function minExecutionFee() external view returns (uint16);

  function whitelistExecutors(address executor) external view returns (bool);
}
