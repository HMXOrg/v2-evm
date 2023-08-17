// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

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

  function getPrice(bool) external pure returns (uint256) {
    return 0;
  }

  function getAums() external view returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = minAum;
    amounts[1] = maxAum;
    return amounts;
  }

  function getAum(bool _isMax) external view returns (uint256) {
    return _isMax ? maxAum : minAum;
  }

  function getAumInUsdg(bool _isMax) external view returns (uint256) {
    return _isMax ? maxAum / 1e12 : minAum / 1e12;
  }

  function addLiquidityForAccount(
    address /* _fundingAccount */,
    address /* _account */,
    address /* _token */,
    uint256 /* _amount */,
    uint256 /* _minUsdg */,
    uint256 /* _minGlp */
  ) external pure returns (uint256) {
    return 0;
  }
}
