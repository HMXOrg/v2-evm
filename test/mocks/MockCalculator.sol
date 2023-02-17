// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ICalculator } from "../../src/contracts/interfaces/ICalculator.sol";

contract MockCalculator is ICalculator {
  uint256 equity;
  uint256 imr;
  uint256 mmr;
  int256 unrealizedPnl;

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setEquity(uint256 _mockEquity) external {
    equity = _mockEquity;
  }

  function setIMR(uint256 _mockImr) external {
    imr = _mockImr;
  }

  function setMMR(uint256 _mockMmr) external {
    mmr = _mockMmr;
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getEquity(address) external view returns (uint) {
    return equity;
  }

  // @todo - Add Description
  function getUnrealizedPnl(address) external view returns (int) {
    return unrealizedPnl;
  }

  // @todo - Add Description
  /// @return imrValueE30 Total imr of trader's account.
  function getIMR(address) external view returns (uint) {
    return imr;
  }

  // @todo - Add Description
  /// @return mmrValueE30 Total mmr of trader's account
  function getMMR(address) external view returns (uint) {
    return mmr;
  }

  // =========================================
  // | ---------- Calculator --------------- |
  // =========================================

  function calculatePositionIMR(
    uint256,
    uint256
  ) external view returns (uint256) {
    return imr;
  }

  function calculatePositionMMR(
    uint256,
    uint256
  ) external view returns (uint256) {
    return mmr;
  }
}
