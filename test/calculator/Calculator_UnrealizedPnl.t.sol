// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base, IPerpStorage } from "./Calculator_Base.t.sol";

contract Calculator_UnrealizedPnl is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  function testRevert_getUnrealizedPnl_invalidAveragePrice() external {
    // Simulate ALICE opening positions
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 0, // This must not happend
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );

    vm.expectRevert(
      abi.encodeWithSignature("ICalculator_InvalidAveragePrice()")
    );
    calculator.getUnrealizedPnl(ALICE);
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_getUnrealizedPnl_noPosition() external {
    // CAROL not has any opening position, so unrealized PNL must return 0
    assertEq(calculator.getUnrealizedPnl(BOB), 0);
  }

  function testCorrectness_getUnrealizedPnl_withOpeningPositions() external {
    // Simulate ALICE opening positions
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );

    calculator.getUnrealizedPnl(ALICE);
  }
}
