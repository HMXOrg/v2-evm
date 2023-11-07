// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IHLPStaking {
  function calculateShare(address rewarder, address user) external view returns (uint256);

  function withdraw(uint256 amount) external;
}
