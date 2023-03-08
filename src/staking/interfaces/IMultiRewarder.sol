// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

interface IMultiRewarder {
  function name() external view returns (string memory);

  function rewardRate() external view returns (uint256);

  function onDeposit(address user, uint256 shareAmount) external;

  function onWithdraw(address user, uint256 shareAmount) external;

  function onHarvest(address user, address receiver) external;

  function pendingReward(address user) external view returns (uint256);
}
