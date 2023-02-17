// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester } from "../../testers/PositionTester.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { ITradeService } from "../../../src/services/interfaces/ITradeService.sol";

// What is this test DONE
// - pre validation
//   - market delisted
//   - market status from oracle is inactive (market close)
//   - price stale
//   - sub account is unhealthy (equity < MMR)
// - success
//   - partially decrease long position
//   - partially decrease short position
//   - fully decrease long position
//   - fully decrease short position
// - revert
//   - try decrease long position which already closed
//   - try decrease short position which already closed
//   - decrease too much long position
//   - decrease too much short position
//   - position remain too tiny size after decrease long position
//   - position remain too tiny size after decrease short position
// What is this test not covered
//   - borrowing fee
//   - funding fee
//   - settlement profit and loss
// - post validation
//   - sub account is unhealthy (equity < MMR) after decreased position

contract TradeService_DecreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // assume ALICE has free collateral for 10,000 USD
    mockCalculator.setEquity(10_000 * 1e30);
  }

  // market delisted
  function testRevert_WhenMarketIsDelistedFromPerp() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // someone delist market
    configStorage.delistMarket(ethMarketIndex);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_MarketIsDelisted.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // market status from oracle is inactive (market close)
  function testRevert_WhenOracleTellMarketIsClose() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // set market status from oracle is inactive
    mockOracle.setMarketStatus(1);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_MarketIsClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // price stale
  function testRevert_WhenPriceStale() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // note: to check price stale is 30 seconds (hardcode) from published seconds
    vm.warp(block.timestamp + 50);

    vm.expectRevert(
      abi.encodeWithSelector(ITradeService.ITradeService_PriceStale.selector)
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // sub account is unhealthy (equity < MMR)
  function testRevert_WhenSubAccountEquityIsLessThanMMR() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // mock MMR as very big number, to make this sub account unhealthy
    mockCalculator.setMMR(type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_SubAccountEquityIsUnderMMR.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30);
  }

  // partially decrease long position
  function testCorrectness_WhenTraderPartiallyDecreaseLongPositionSize()
    external
  {
    // ALICE open LONG position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 10,000 TOKENs
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(_positionId);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30);

    // check position after decrease
    // open interest delta = open interest * position size to decrease / position size
    //                     = 10000 * 500000 / 1000000 = 5000
    PositionTester.DecreasePositionAssertionData
      memory _assertData = PositionTester.DecreasePositionAssertionData({
        decreasedPositionSize: 500_000 * 1e30,
        avgPriceDelta: 0,
        reserveValueDelta: 45_000 * 1e30,
        openInterestDelta: 5_000 * 1e18
      });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // partially decrease short position
  function testCorrectness_WhenTraderPartiallyDecreaseShortPositionSize()
    external
  {
    // ALICE open SHORT position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 10,000 TOKENs
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // cache position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(_positionId);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30);

    // check position after decrease
    // open interest delta = open interest * position size to decrease / position size
    //                     = 10000 * 500000 / 1000000 = 5000
    PositionTester.DecreasePositionAssertionData
      memory _assertData = PositionTester.DecreasePositionAssertionData({
        decreasedPositionSize: 500_000 * 1e30,
        avgPriceDelta: 0,
        reserveValueDelta: 45_000 * 1e30,
        openInterestDelta: 5_000 * 1e18
      });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // fully decrease long position
  function testCorrectness_WhenTraderFullyDecreaseLongPositionSize() external {
    // ALICE open LONG position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 10,000 TOKENs
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(_positionId);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // check position after decrease
    // open interest delta = open interest * position size to decrease / position size
    //                     = 10000 * 1000000 / 1000000 = 10000
    PositionTester.DecreasePositionAssertionData
      memory _assertData = PositionTester.DecreasePositionAssertionData({
        decreasedPositionSize: 1_000_000 * 1e30,
        avgPriceDelta: 0,
        reserveValueDelta: 90_000 * 1e30,
        openInterestDelta: 10_000 * 1e18
      });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // fully decrease short position
  function testCorrectness_WhenTraderFullyDecreaseShortPositionSize() external {
    // ALICE open SHORT position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 10,000 TOKENs
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // cache position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(_positionId);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // check position after decrease
    // open interest delta = open interest * position size to decrease / position size
    //                     = 10000 * 1000000 / 1000000 = 10000
    PositionTester.DecreasePositionAssertionData
      memory _assertData = PositionTester.DecreasePositionAssertionData({
        decreasedPositionSize: 1_000_000 * 1e30,
        avgPriceDelta: 0,
        reserveValueDelta: 90_000 * 1e30,
        openInterestDelta: 10_000 * 1e18
      });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // try decrease long position which already closed
  function testRevert_WhenTraderDecreaseLongPositionWhichAlreadyClosed()
    external
  {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE try to decrease again
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_PositionAlreadyClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
  }

  // try decrease short position which already closed
  function testRevert_WhenTraderDecreaseShortPositionWhichAlreadyClosed()
    external
  {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE try to decrease again
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_PositionAlreadyClosed.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
  }

  // decrease too much long position
  function testRevert_WhenTraderDecreaseTooMuchLongPositionSize() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_DecreaseTooHighPositionSize.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30);
  }

  // decrease too much short position
  function testRevert_WhenTraderDecreaseTooMuchShortPositionSize() external {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_DecreaseTooHighPositionSize.selector
      )
    );
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30);
  }

  // position remain too tiny size after decrease long position
  function testRevert_AfterDecreaseLongPositionAndRemainPositionSizeIsTooTiny()
    external
  {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_TooTinyPosition.selector
      )
    );
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29);
  }

  // position remain too tiny size after decrease short position
  function testRevert_AfterDecreaseShortPositioAndRemainPositionSizeIsTooTiny()
    external
  {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);
    vm.expectRevert(
      abi.encodeWithSelector(
        ITradeService.ITradeService_TooTinyPosition.selector
      )
    );
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29);
  }

  // note: this case need to open many position and then decrease 1 with a lot of loss size
  //       now we still not support about settle profit and loss todo: make this test valid
  //       may can move this to complex test case
  // function testRevert_AfterPositionDecreasedAndSubAccountEquityIsLessThanMMR()
  //   external
  // {}
}
