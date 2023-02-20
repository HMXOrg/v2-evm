// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICalculator {
  function getEquity(address _subAccount) external returns (uint256);

  function getFreeCollateral(address _subAccount) external returns (uint256);

  function getMMR(address _subAccount) external returns (uint256);

  function getIMR(bytes32 _marketId, uint256 _size) external returns (uint256);

  function getAum() external view returns (uint256);

  function getPlpValue() external view returns (uint256);
}
