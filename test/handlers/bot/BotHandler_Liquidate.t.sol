// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

contract BotHandler_Liquidate is BotHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevert_liquidate_WhenSomeoneCallBotHandler() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
    botHandler.liquidate(ALICE, prices);
  }

  function testCorrectness_liquidate() external {
    botHandler.liquidate(ALICE, prices);
  }
}
