// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library AddressUtils {
  function toBytes32(address _addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr))) << 96;
  }
}
