// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { TradeService_Base } from "./TradeService_Base.t.sol";

contract TradeService_DecreasePosition is TradeService_Base {
  // -- pre validation
  // validate MMR
  // validate Market config
  // validate position size
  // validate decrease position size
  // -- normal case
  // able to decrease long position
  // able to decrease short position
  // -- post validation
  // validate MMR in post validation
  // validate too tiny position
}
