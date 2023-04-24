// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

contract MockGlpManager is IGmxGlpManager {
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

  function addLiquidityForAccount(
    address _fundingAccount,
    address _account,
    address _token,
    uint256 _amount,
    uint256 _minUsdg,
    uint256 _minGlp
  ) external returns (uint256) {
    return 0;
  }
}
