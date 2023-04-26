// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseBridgeableToken } from "./base/BaseBridgeableToken.sol";

contract EsHMX is BaseBridgeableToken {
  constructor(
    bool isBurnAndMint_
  ) BaseBridgeableToken("Escrowed HMX", "esHMX", 18, type(uint256).max, type(uint256).max, isBurnAndMint_) {}
}
