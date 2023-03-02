// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MarketTradeHandler } from "../../../src/handlers/MarketTradeHandler.sol";
import { MarketTradeHandler_Base, IPerpStorage } from "./MarketTradeHandler_Base.t.sol";
import { IMarketTradeHandler } from "../../../src/handlers/interfaces/IMarketTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try sell with _sellSizeE30 = 0
// - success
//   - Try sell with no position existed
//   - Try sell with long position existed
//   - Try sell with short position existed, with smaller _sellSizeE30 than existing size
//   - Try sell with short position existed, with larger _sellSizeE30 than existing size

contract MarketTradeHandler_Sell is MarketTradeHandler_Base {
  event LogSell(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    uint256 _sellSizeE30,
    uint256 _longDecreasingSizeE30,
    uint256 _shortIncreasingSizeE30
  ); // Redeclare here for expectEmit

  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenSellWithZeroSize() external {
    vm.expectRevert(abi.encodeWithSignature("IMarketTradeHandler_ZeroSizeInput()"));
    marketTradeHandler.sell(ALICE, 0, 0, 0, address(weth), prices);
  }

  function testCorrectness_WhenSellWithNoExistingPosition() external {
    // it should increase position with the sell size right away
    uint256 _sellSize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogSell(ALICE, 0, 0, _sellSize, 0, _sellSize);

    marketTradeHandler.sell(ALICE, 0, 0, _sellSize, address(weth), prices);
  }

  function testCorrectness_WhenSellWithExistingShortPosition() external {
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

    // it should increase position with the sell size right away
    uint256 _sellSize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogSell(ALICE, 0, 0, _sellSize, 0, _sellSize);

    marketTradeHandler.sell(ALICE, 0, 0, _sellSize, address(weth), prices);
  }

  function testCorrectness_WhenSellWithExistingLongPosition_WithSmallSellSize() external {
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

    // it should decrease position with the sell size, without increasing position
    uint256 _sellSize = 10_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogSell(ALICE, 0, 0, _sellSize, _sellSize, 0);

    marketTradeHandler.sell(ALICE, 0, 0, _sellSize, address(weth), prices);
  }

  function testCorrectness_WhenSellWithExistingLongPosition_WithLargeSellSize() external {
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

    // it should decrease position with 15_000 size, and increasing position with 5_000 size
    uint256 _sellSize = 20_000 * 1e30;
    vm.expectEmit(false, false, false, true, address(marketTradeHandler));
    emit LogSell(ALICE, 0, 0, _sellSize, 15_000 * 1e30, 5_000 * 1e30);

    marketTradeHandler.sell(ALICE, 0, 0, _sellSize, address(weth), prices);
  }
}
