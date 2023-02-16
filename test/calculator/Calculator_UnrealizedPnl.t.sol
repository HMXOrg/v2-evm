// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";

contract Calculator_UnrealizedPnl is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_getUnrealizedPnl_noPosition() external {
    // CAROL not has any opening position, so unrealized PNL must return 0
    assertEq(calculator.getUnrealizedPnl(CAROL), 0);
  }

  function testCorrectness_getUnrealizedPnl_withOpeningPositions() external {
    calculator.getUnrealizedPnl(ALICE);
  }
}
