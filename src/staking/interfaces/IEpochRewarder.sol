// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IEpochRewarder {
  function name() external view returns (string memory);

  function onDeposit(uint256 epochTimestamp, address user, uint256 shareAmount) external;

  function onWithdraw(uint256 epochTimestamp, address user, uint256 shareAmount) external;

  function onHarvest(uint256 epochTimestamp, address user, address receiver) external;

  function pendingReward(
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address userAddress
  ) external view returns (uint256);

  function feed(uint256 epochTimestamp, uint256 feedAmount) external;

  function setFeeder(address feeder_) external;

  function getCurrentEpochTimestamp() external view returns (uint256 epochTimestamp);
}
