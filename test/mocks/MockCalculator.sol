// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";

contract MockCalculator is ICalculator {
  uint256 equity;
  uint256 mmr;
  uint256 imrE30;
  uint256 mmrE30;
  uint256 equityValueE30;
  int256 unrealizedPnlE30;
  uint256 imrValueE30;
  uint256 mmrValueE30;

  function setEquity(uint256 _mockEquity) external {
    equity = _mockEquity;
  }

  function setMMR(uint256 _mockMmr) external {
    mmr = _mockMmr;
  }

  function calIMR(uint256, uint256) external view returns (uint256) {
    return imrE30;
  }

  function calMMR(uint256, uint256) external view returns (uint256) {
    return mmrE30;
  }

  function getEquity(address) external view returns (uint) {
    return equityValueE30;
  }

  // @todo - Add Description
  function getUnrealizedPnl(address) external view returns (int) {
    return unrealizedPnlE30;
  }

  // @todo - Add Description
  /// @return imrValueE30 Total imr of trader's account.
  function getIMR(address) external view returns (uint) {
    return imrValueE30;
  }

  // @todo - Add Description
  /// @return mmrValueE30 Total mmr of trader's account
  function getMMR(address) external view returns (uint) {
    return mmrValueE30;
  }
}
