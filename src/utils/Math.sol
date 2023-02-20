// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library Math {
  function abs(int256 x) external pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }
}
