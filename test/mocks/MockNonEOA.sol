// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

contract MockNonEOA {
  function someFunction() external pure returns (uint256) {
    return 1;
  }
}
