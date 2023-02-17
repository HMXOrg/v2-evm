// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";

contract MockCalculator is ICalculator {
  uint256 equity;
  uint256 freeCollateral;
  uint256 mmr;
  uint256 imr;
  uint256 aum;

  function setEquity(uint256 _mockEquity) external {
    equity = _mockEquity;
  }

  function setMMR(uint256 _mockMmr) external {
    mmr = _mockMmr;
  }

  function getEquity(address /*_subAccount*/) external view returns (uint256) {
    return equity;
  }

  function getMMR(address /*_subAccount*/) external view returns (uint256) {
    return mmr;
  }

  function getFreeCollateral(
    address /*_subAccount*/
  ) external view returns (uint256) {
    return freeCollateral;
  }

  function getIMR(
    bytes32 /*_marketId*/,
    uint256 /*_size*/
  ) external view returns (uint256) {
    return imr;
  }

  function getAum() external view returns (uint256) {
    return aum;
  }
}
