// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseMintableToken } from "./base/BaseMintableToken.sol";

contract TLC is BaseMintableToken {
  constructor() BaseMintableToken("Trader Loyalty Credit", "TLC", 18, type(uint256).max, type(uint256).max) {}
}
