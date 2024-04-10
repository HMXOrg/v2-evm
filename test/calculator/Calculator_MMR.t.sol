// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

// What is this test DONE
// - success
//   - Try get MMR with no opening position on trader's sub account
//   - Try get MMR with LONG opening position on trader's sub account
//   - Try get MMR with SHORT opening position on trader's sub account

contract Calculator_MMR is Calculator_Base {
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
        lastFundingAccrued: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        lastIncreaseSize: 0
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
        lastFundingAccrued: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        lastIncreaseSize: 0
      })
    );
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try get MMR with no opening position on trader's sub account
  function testCorrectness_getMMR_noOpeningPositions() external {
    // If no opening position, MMR should return 0
    assertEq(calculator.getMMR(CAROL), 0);
  }

  // Try get MMR with LONG opening position on trader's sub account
  function testCorrectness_getMMR_longPosition() external {
    // ALICE contains 1 opening position, so should get MMR return
    assertEq(calculator.getMMR(ALICE), 500 * 1e30);
  }

  // Try get MMR with SHORT opening position on trader's sub account
  function testCorrectness_getMMR_shortPosition() external {
    // BOB contains 1 opening position, so should get MMR return
    assertEq(calculator.getMMR(BOB), 250 * 1e30);
  }
}
