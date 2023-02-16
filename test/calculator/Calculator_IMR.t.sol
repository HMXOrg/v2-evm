// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";

contract Calculator_IMR is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_getIMR_noOpeningPositions() external {
    // If no opening position, IMR should return 0
    assertEq(calculator.getIMR(CAROL), 0);
  }

  function testCorrectness_getIMR_longPosition() external {
    // ALICE contains 1 opening position, so should get IMR return
    assertEq(calculator.getIMR(ALICE), 1000 * 1e30);
  }

  function testCorrectness_getIMR_shortPosition() external {
    // BOB contains 1 opening position, so should get IMR return
    assertEq(calculator.getIMR(BOB), 500 * 1e30);
  }
}
