// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { TradeService_Base } from "./TradeService_Base.t.sol";

contract TradeService_DecreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // increase position for decrease test
  }

  // -- pre validation
  // validate MMR
  function testRevert_WhenSubAccountEquityIsLessThanMMR() external {}

  // validate Market config
  // validate position size is 0
  function testRevert_WhenPositionIsAlreadyClosed() external {}

  // validate decrease position size is too tiny
  function testRevert_WhenTraderDecreaseWithTinySize() external {}

  // -- normal case
  // able to decrease long position
  function testCorrectness_WhenTraderDecreaseLongPosition() external {}

  // able to decrease short position
  function testCorrectness_WhenTraderDecreaseShortPosition() external {}

  // -- borrowing fee
  // -- funding fee
  // -- settlement
  // profit
  // loss
  // -- post validation
  // validate MMR in post validation
  function testRevert_WhenSubAccountEquityIsLessThanMMRAfterPositionDecreased()
    external
  {}

  // validate too tiny position
  function testRevert_RemainingPositionSizeIsTooTiny() external {}

  // -- bad debt
}
