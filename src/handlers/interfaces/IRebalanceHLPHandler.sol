// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

interface IRebalanceHLPHandler {
  // error
  error RebalanceHLPHandler_ParamsIsEmpty();
  error RebalanceHLPHandler_AddressIsZero();
  error RebalanceHLPHandler_AmountIsZero();
  error RebalanceHLPHandler_InvalidTokenAddress();
  error RebalanceHLPHandler_InvalidTokenAmount();
  error RebalanceHLPHandler_HlpTvlDropExceedMin();
  error RebalanceHLPHandler_NotWhiteListed();

  // execute logic
  function addGlp(
    IRebalanceHLPService.AddGlpParams[] calldata params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external returns (uint256 receivedGlp);

  function withdrawGlp(
    IRebalanceHLPService.WithdrawGlpParams[] calldata params,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external returns (IRebalanceHLPService.WithdrawGlpResult[] memory result);

  // Setters
  function setMinHLPValueLossBPS(uint16 minTvlBPS) external;

  function setRebalanceHLPService(address _newService) external;

  function setWhiteListExecutor(address _executor, bool _isAllow) external;

  // Getters
  function service() external view returns (IRebalanceHLPService);

  function sglp() external view returns (IERC20Upgradeable);

  function vaultStorage() external view returns (IVaultStorage);

  function calculator() external view returns (ICalculator);

  function minHLPValueLossBPS() external view returns (uint16);
}
