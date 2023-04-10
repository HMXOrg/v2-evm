// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IGmxRewardTracker {
  function rewardToken() external view returns (address);

  function claim(address _receiver) external returns (uint256);
}
