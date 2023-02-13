// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library AddressUtils {
  function toBytes32(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr))) << 96;
  }
}
