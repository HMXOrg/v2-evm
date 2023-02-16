// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";

contract Calculator_MMR is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_getMMR_noOpeningPositions() external {
    // If no opening position, MMR should return 0
    assertEq(calculator.getMMR(CAROL), 0);
  }

  function testCorrectness_getMMR_longPosition() external {
    // ALICE contains 1 opening position, so should get MMR return
    assertEq(calculator.getMMR(ALICE), 500000000000000000000000000000000);
  }

  function testCorrectness_getMMR_shortPosition() external {
    // BOB contains 1 opening position, so should get MMR return
    assertEq(calculator.getMMR(BOB), 250000000000000000000000000000000);
  }
}
