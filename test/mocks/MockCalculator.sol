// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";

contract MockCalculator is ICalculator {
  uint256 equity;
  uint256 freeCollateral;
  uint256 mmr;
  uint256 imr;
  uint256 aum;
  uint256 plpValue;

  function setEquity(uint256 _mockEquity) external {
    equity = _mockEquity;
  }

  function setMMR(uint256 _mockMmr) external {
    mmr = _mockMmr;
  }

  function setFreeCollateral(uint256 _mockFreeCollateral) external {
    freeCollateral = _mockFreeCollateral;
  }

  function setPlpValue(uint256 _mockPlpValue) external {
    plpValue = _mockPlpValue;
  }

  function setIMR(uint256 _mockImr) external {
    imr = _mockImr;
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

  function getPlpValue() external view returns (uint256) {
    return plpValue;
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
