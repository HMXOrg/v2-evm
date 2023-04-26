// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseBridgeableToken } from "./base/BaseBridgeableToken.sol";

contract HMX is BaseBridgeableToken {
  constructor(
    bool isBurnAndMint_
  ) BaseBridgeableToken("HMX", "HMX", 18, 1_000_000 ether, 10_000_000 ether, isBurnAndMint_) {}
}
