// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

import { PositionTester } from "../../testers/PositionTester.sol";

/// @title BotHandler_SetPositionManagers
/// @notice The purpose is test BotHandler contract able to set position manager
contract BotHandler_SetPositionManagers is BotHandler_Base {
  // What this test DONE
  // - correctness
  //    - allow position manager
  //    - disallow posisition manager
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_WhenSetPositionManagers() external {
    // check ALICE, BOB permission first
    assertEq(botHandler.positionManagers(ALICE), false);
    assertEq(botHandler.positionManagers(BOB), false);

    // allow ALICE, BOB position managers
    address[] memory _positionManagers = new address[](2);
    _positionManagers[0] = ALICE;
    _positionManagers[1] = BOB;

    botHandler.setPositionManagers(_positionManagers, true);

    // check ALICE, BOB permission again
    assertEq(botHandler.positionManagers(ALICE), true);
    assertEq(botHandler.positionManagers(BOB), true);

    address[] memory _positionManagers2 = new address[](1);
    _positionManagers2[0] = ALICE;
    // disallow only ALICE back
    botHandler.setPositionManagers(_positionManagers2, false);

    // check ALICE, BOB permission again
    assertEq(botHandler.positionManagers(ALICE), false);
    assertEq(botHandler.positionManagers(BOB), true);
  }
}
