// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MarketTradeHandler } from "../../../src/handlers/MarketTradeHandler.sol";
import { MarketTradeHandler_Base, IPerpStorage } from "./MarketTradeHandler_Base.t.sol";
import { IMarketTradeHandler } from "../../../src/handlers/interfaces/IMarketTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try buy with _buySizeE30 = 0
// - success
//   - Try buy with no position existed
//   - Try buy with long position existed
//   - Try buy with short position existed, with smaller _buySizeE30 than existing size
//   - Try buy with short position existed, with larger _buySizeE30 than existing size

contract MarketTradeHandler_Buy is MarketTradeHandler_Base {
  event LogBuy(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _buySizeE30,
    uint256 _shortDecreasingSizeE30,
    uint256 _longIncreasingSizeE30
  ); // Redeclare here for expectEmit

  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenBuyWithZeroSize() external {
    vm.expectRevert(abi.encodeWithSignature("IMarketTradeHandler_ZeroSizeInput()"));
    marketTradeHandler.buy(ALICE, 0, 0, 0, prices);
  }

  function testCorrectness_WhenBuyWithNoExistingPosition() external {
    // it should increase position with the buy size right away
    uint256 _buySize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogBuy(ALICE, 0, 0, _buySize, 0, _buySize);

    marketTradeHandler.buy(ALICE, 0, 0, _buySize, prices);
  }

  function testCorrectness_WhenBuyWithExistingLongPosition() external {
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: ALICE,
        subAccountId: 0,
        marketIndex: 0,
        positionSizeE30: 15_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 1_350 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // it should increase position with the buy size right away
    uint256 _buySize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogBuy(ALICE, 0, 0, _buySize, 0, _buySize);

    marketTradeHandler.buy(ALICE, 0, 0, _buySize, prices);
  }

  function testCorrectness_WhenBuyWithExistingShortPosition_WithSmallBuySize() external {
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: ALICE,
        subAccountId: 0,
        marketIndex: 0,
        positionSizeE30: -15_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 1_350 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // it should decrease position with the buy size, without increasing position
    uint256 _buySize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogBuy(ALICE, 0, 0, _buySize, _buySize, 0);

    marketTradeHandler.buy(ALICE, 0, 0, _buySize, prices);
  }

  function testCorrectness_WhenBuyWithExistingShortPosition_WithLargeBuySize() external {
    mockPerpStorage.setPositionBySubAccount(
      ALICE,
      IPerpStorage.Position({
        primaryAccount: ALICE,
        subAccountId: 0,
        marketIndex: 0,
        positionSizeE30: -15_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 1_350 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // it should decrease position with 15_000 size, and increasing position with 5_000 size
    uint256 _buySize = 20_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogBuy(ALICE, 0, 0, _buySize, 15_000 * 1e30, 5_000 * 1e30);

    marketTradeHandler.buy(ALICE, 0, 0, _buySize, prices);
  }
}
