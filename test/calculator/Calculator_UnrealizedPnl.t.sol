// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

// What is this test DONE
// - success
//   - Try get Unrealized PNL with no opening position on trader's sub account
//   - Try get Unrealized PNL with LONG opening position with PROFIT on trader's sub account
//   - Try get Unrealized PNL with LONG opening position with LOSS on trader's sub account
//   - Try get Unrealized PNL with SHORT opening position with PROFIT on trader's sub account
//   - Try get Unrealized PNL with SHORT opening position with LOSS on trader's sub account
// What is this test not covered
//   - Price Stale checking from Oracle

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
        realizedPnl: 0,
        openInterest: 0
      })
    );

    vm.expectRevert(abi.encodeWithSignature("ICalculator_InvalidAveragePrice()"));
    calculator.getUnrealizedPnl(ALICE, 0, 0);
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try get Unrealized PNL with no opening position on trader's sub account
  function testCorrectness_getUnrealizedPnl_noPosition() external {
    // CAROL not has any opening position, so unrealized PNL must return 0
    assertEq(calculator.getUnrealizedPnl(BOB, 0, 0), 0);
  }

  // Try get Unrealized PNL with LONG opening position with PROFIT on trader's sub account
  function testCorrectness_getUnrealizedPnl_profitLongPosition() external {
    // Simulate ALICE opening LONG position with profit
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Mock WETH Price to 2,000
    mockOracle.setPrice(2_000 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = (100,000 * (2,000 - 1,600))/1,600 = 25,000 in Profit
    // UnrealizedPnl = 25,000 * 0.8 = 20,000
    assertEq(calculator.getUnrealizedPnl(ALICE, 0, 0), 20_000 * 1e30);
  }

  // Try get Unrealized PNL with SHORT opening position with PROFIT on trader's sub account
  function testCorrectness_getUnrealizedPnl_profitShortPosition() external {
    // Simulate ALICE opening SHORT positions with profit
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: -100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Mock WETH Price to 1,400
    mockOracle.setPrice(1_400 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = (-100,000 * (1,600 - 1,400))/1,600 = 12,500 in Profit
    // UnrealizedPnl = 12,500 * 0.8 = 10,000
    assertEq(calculator.getUnrealizedPnl(ALICE, 0, 0), 10_000 * 1e30);
  }

  // Try get Unrealized PNL with LONG opening position with LOSS on trader's sub account
  function testCorrectness_getUnrealizedPnl_notProfitLongPosition() external {
    // Simulate ALICE opening LONG position with loss
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Mock WETH Price to 1,400
    mockOracle.setPrice(1_400 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = -1 * (100,000 * (2,000 - 1,600))/1,600 = -12,500 in Loss
    // UnrealizedPnl = -12,500
    assertEq(calculator.getUnrealizedPnl(ALICE, 0, 0), -12_500 * 1e30);
  }

  // Try get Unrealized PNL with SHORT opening position with LOSS on trader's sub account
  function testCorrectness_getUnrealizedPnl_notProfitShortPosition() external {
    // Simulate ALICE opening SHORT positions with Loss
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: address(1),
        subAccountId: 1,
        marketIndex: 0, //WETH
        positionSizeE30: -100_000 * 1e30,
        avgEntryPriceE30: 1_600 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Mock WETH Price to 1,800
    mockOracle.setPrice(1_800 * 1e30);
    configStorage.setPnlFactor(0.8 * 1e4);

    // Calculate unrealized pnl from ALICE's position
    // UnrealizedPnl = ABS(positionSize - priceDelta)/avgEntryPrice
    // If Profit then UnrealizedPnl = UnrealizedPnl * pnlFactor
    // UnrealizedPnl = (-100,000 * (1,600 - 1,800))/1,600 = 12,500 in Loss
    // UnrealizedPnl = -12,500
    assertEq(calculator.getUnrealizedPnl(ALICE, 0, 0), -12_500 * 1e30);
  }
}
