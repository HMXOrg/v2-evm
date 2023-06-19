// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

contract BotHandler_Liquidate is BotHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevert_liquidate_WhenSomeoneCallBotHandler() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
    botHandler.liquidate(ALICE, priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
  }

  function testCorrectness_liquidate() external {
    botHandler.liquidate(ALICE, priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
  }
}
