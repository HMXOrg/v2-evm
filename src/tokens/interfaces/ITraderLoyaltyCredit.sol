// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITraderLoyaltyCredit {
  function mint(address account, uint256 amount) external;

  function getCurrentEpochTimestamp() external view returns (uint256 epochTimestamp);

  function setMinter(address _minter, bool _mintable) external;

  function balanceOf(uint256 epochTimestamp, address account) external view returns (uint256);

  function totalSupplyByEpoch(uint256 epochTimestamp) external view returns (uint256);
}
