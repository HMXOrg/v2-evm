// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

import { PositionTester } from "../../testers/PositionTester.sol";

/// @title BotHandler_SetTradeService
/// @notice The purpose is test BotHandler contract able to reset trade service
contract BotHandler_SetTradeService is BotHandler_Base {
  // What this test DONE
  // - correctness
  //   - change trade service
  // - revert
  //   - invalid address, revert on sanity check
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_WhenSetTradeService() external {
    // check trade service address
    assertEq(botHandler.tradeService(), address(tradeService));

    address _newAddress = address(mockTradeService);
    botHandler.setTradeService(_newAddress);

    // check new trade service address
    assertEq(botHandler.tradeService(), _newAddress);
  }

  function testRevert_WhenSetInvalidTradeService() external {
    vm.expectRevert();
    botHandler.setTradeService(address(0));
  }
}
