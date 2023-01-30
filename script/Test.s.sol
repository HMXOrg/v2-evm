// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console2} from "forge-std/console2.sol";

contract TestScript {
  function run() external view {
    console2.logBytes32(keccak256("com.perp88.addLiquidity"));
    console2.logBytes32(keccak256("com.perp88.removeLiquidity"));
    console2.logBytes32(keccak256("com.perp88.swap"));
    console2.logBytes32(keccak256("com.perp88.increasePosition"));
    console2.logBytes32(keccak256("com.perp88.decreasePosition"));
    console2.logBytes32(keccak256("com.perp88.liquidatePosition"));
    console2.logBytes32(bytes32(uint256(1)));
  }
}
