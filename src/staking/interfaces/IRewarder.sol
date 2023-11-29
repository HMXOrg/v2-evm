// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IRewarder {
  function name() external view returns (string memory);

  function rewardRate() external view returns (uint256);

  function onDeposit(address user, uint256 shareAmount) external;

  function onWithdraw(address user, uint256 shareAmount) external;

  function onHarvest(address user, address receiver) external;

  function pendingReward(address user) external view returns (uint256);

  function feed(uint256 feedAmount, uint256 duration) external;

  function accRewardPerShare() external view returns (uint128);

  function userRewardDebts(address user) external view returns (int256);

  function lastRewardTime() external view returns (uint64);

  function setFeeder(address feeder_) external;

  function feedWithExpiredAt(uint256 feedAmount, uint256 expiredAt) external;
}
