// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICalculator {
  function getEquity(address _subAccount) external returns (uint256);

  function getMMR(address _subAccount) external returns (uint256);
}
