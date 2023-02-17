// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base, IPerpStorage } from "./Calculator_Base.t.sol";

contract Calculator_IMR is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();

    // Simulate ALICE contains 1 opening LONG position
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0,
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Simulate BOB contains 1 opening SHORT position
    mockPerpStorage.setPositionBySubAccount(
      BOB,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0,
        positionSizeE30: -50_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );
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
