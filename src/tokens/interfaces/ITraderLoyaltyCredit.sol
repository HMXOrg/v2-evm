// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

interface ITraderLoyaltyCredit {
  function mint(address account, uint256 amount) external;

  function getCurrentEpochTimestamp() external view returns (uint256 epochTimestamp);

  function feedReward(uint256 epochTimestamp, uint256 amount) external;

  function claimReward(uint256 startEpochTimestamp, uint256 noOfEpochs, address userAddress) external;

  function setMinter(address _minter, bool _mintable) external;

  function pendingReward(
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    address userAddress
  ) external view returns (uint256);
}
