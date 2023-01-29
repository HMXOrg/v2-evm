// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console2} from "forge-std/console2.sol";

contract TestScript {
  function run() external view {
    address a = address(0x685B1ded8013785d6623CC18D214320b6Bb64759);
    console2.logBytes32(bytes32(uint256(uint160(a))) << 96);
  }
}
