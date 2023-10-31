// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";

interface IRebalanceHLPv2Handler {
  function weth() external view returns (IWNative);

  function minExecutionFee() external view returns (uint256);

  function createDepositOrders(
    IRebalanceHLPv2Service.DepositParams[] calldata _depositParams,
    uint256 _executionFee
  ) external payable returns (bytes32[] memory);

  function createWithdrawalOrders(
    IRebalanceHLPv2Service.WithdrawalParams[] calldata _withdrawalParams,
    uint256 _executionFee
  ) external payable returns (bytes32[] memory);

  function setWhitelistExecutor(address _executor, bool _isAllow) external;
}
