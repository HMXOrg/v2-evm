// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";

contract MockCalculator is ICalculator {
  uint256 equity;
  uint256 mmr;

  function setEquity(uint256 _mockEquity) external {
    equity = _mockEquity;
  }

  function setMMR(uint256 _mockMmr) external {
    mmr = _mockMmr;
  }

  function getEquity(address _subAccount) external view returns (uint256) {
    return equity;
  }

  function getMMR(address _subAccount) external view returns (uint256) {
    return mmr;
  }
}
