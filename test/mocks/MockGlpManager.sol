// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract MockGlpManager {
  uint256 public maxAum;
  uint256 public minAum;

  function setMinAum(uint256 _minAum) external {
    minAum = _minAum;
  }

  function setMaxAum(uint256 _maxAum) external {
    maxAum = _maxAum;
  }

  function getAum(bool _isMax) external view returns (uint256) {
    return _isMax ? maxAum : minAum;
  }

  function getAumInUsdg(bool _isMax) external view returns (uint256) {
    return _isMax ? maxAum / 1e12 : minAum / 1e12;
  }
}
