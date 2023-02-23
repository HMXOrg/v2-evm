// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester } from "../../testers/PositionTester.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

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
//   - trading fee
//   - settlement profit
//   - settlement loss
//   - settlement fee
//   - protocol curcuit break
//   - trading curcuit break
// - post validation
//   - sub account is unhealthy (equity < MMR) after decreased position

contract TradeService_DecreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);

    // assume ALICE has free collateral for 10,000 USD
    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // mock PLP token for profitable trader
    // related with TVL 1,000,000 USD, let provide 1,000,000 WETH (price 1$)
    vaultStorage.addPLPLiquidity(address(weth), 1_000_000 ether);
  }

  // market delisted
  function testRevert_WhenMarketIsDelistedFromPerp() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // someone delist market
    configStorage.delistMarket(ethMarketIndex);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsDelisted()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30, address(weth));
  }

  // market status from oracle is inactive (market close)
  function testRevert_WhenOracleTellMarketIsClose() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // set market status from oracle is inactive
    mockOracle.setMarketStatus(1);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsClosed()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30, address(weth));
  }

  // price stale
  function testRevert_WhenPriceStale() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // make price stale in mock oracle middleware
    mockOracle.setPriceStale(true);

    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30, address(weth));
  }

  // sub account is unhealthy (equity < MMR)
  function testRevert_WhenSubAccountEquityIsLessThanMMR() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // mock MMR as very big number, to make this sub account unhealthy
    mockCalculator.setMMR(ALICE, type(uint256).max);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_SubAccountEquityIsUnderMMR()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 10 * 1e30, address(weth));
  }

  // partially decrease long position
  // settle profit on long position
  function testCorrectness_WhenTraderPartiallyDecreaseLongPositionSizeWithProfit() external {
    // Prepare for this test

    // ALICE open LONG position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // price change to 1.05 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(1.05 * 1e30);

    // BOB open LONG position
    // sub account id - 0
    // position size  - 500,000 USD
    // IMR            - 5,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 476,190.476190476190476190 TOKENs
    // average price  - 1.05 USD
    openPosition(BOB, 0, ethMarketIndex, 500_000 * 1e30);

    // recalculate new long average price after BOB open position
    // global long pnl = global long size * (current price - global avg price) / global avg price
    //                 = 1000000 * (1.05 - 1) / 1 = +50000 USD
    // new global long size = 15000000 (global long size + BOB long position size)
    // new average long price = new global size * current price / new global size with pnl
    //                        = 1500000 * 1.05 / 1500000 + (+50000) = 1.016129032258064516129032258064 USD
    // THEN MARKET state
    // long position size - 1,500,000 USD
    // open interest      - 1,476,190.476190476190476190 TOKENs
    // average price      - 1.016129032258064516129032258064 USD

    // Start test

    address _tpToken = address(weth); // take profit token

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // ALICE decrease position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, _tpToken);

    // recalculate long average price after ALICE decrease position
    // global long pnl = global long size * (current price - global long avg price) / global avg price
    //                 = 1500000 * (1.05 - 1.016129032258064516129032258064) / 1.016129032258064516129032258064
    //                 = +50000.000000000000000000000000787301 USD
    // position realized pnl = decreased position size * (current price - position avg price) / position avg price
    //                       = 500000 * (1.05 - 1) / 1 = +25000 USD
    // new global long pnl = global long pnl - position relaized pnl
    //                     = +50000.000000000000000000000000787301 - (+25000)
    //                     = +25000.000000000000000000000000787301 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 500000 / 1000000 = 500000
    // new global long size = 1000000 USD (global long size - decreased position size)
    // new long average price (global) = current price * new global long size / new global long size + new global long pnl
    //                                 = 1.05 * 1000000 / (1000000 + (+25000.000000000000000000000000787301))
    //                                 = 1.024390243902439024390243902438 USD
    // token profit amount = position realized pnl / price
    //                     = +25000 / 1.05 = 23809.523809523809523809 ether
    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // profit
      tpToken: _tpToken,
      profitAmount: 23809.523809523809523809 ether,
      // position info
      decreasedPositionSize: 500_000 * 1e30,
      reserveValueDelta: 45_000 * 1e30,
      openInterestDelta: 500_000 * 1e18,
      // average prices
      newPositionAveragePrice: 1 * 1e30,
      newLongGlobalAveragePrice: 1.024390243902439024390243902438 * 1e30,
      newShortGlobalAveragePrice: 0
    });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // partially decrease short position
  // settle loss on short position
  function testCorrectness_WhenTraderPartiallyDecreaseShortPositionSizeWithLoss() external {
    // Prepare for this test

    // ALICE open SHORT position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // price change to 1.05 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(1.05 * 1e30);

    // BOB open SHORT position
    // sub account id - 0
    // position size  - 500,000 USD
    // IMR            - 5,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 476,190.476190476190476190 TOKENs
    // average price  - 1.05 USD
    openPosition(BOB, 0, ethMarketIndex, -500_000 * 1e30);

    // recalculate new short average price after BOB open position
    // global short pnl = global short size * (global short avg price - current price) / global short avg price
    //                 = 1000000 * (1 - 1.05) / 1 = -50000 USD
    // new global short size = 15000000 (global short size + BOB position size)
    // new average short price = new global short size * current price / new global short size - global short pnl
    //                        = 1500000 * 1.05 / 1500000 - (-50000) = 1.016129032258064516129032258064 USD
    // THEN MARKET state
    // short position size - 1,500,000 USD
    // open interest       - 1,476,190.476190476190476190 TOKENs
    // average price       - 1.016129032258064516129032258064 USD

    // Start test

    // in this case trader has loss, then we don't care about take profit token
    address _tpToken = address(0);

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // ALICE decrease position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, _tpToken);

    // recalculate short average price after ALICE decrease position
    // global short pnl = global short size * (global short avg price - current price) / global avg price
    //                 = 1500000 * (1.016129032258064516129032258064 - 1.05) / 1.016129032258064516129032258064
    //                 = -50000.000000000000000000000000787301 USD
    // position realized pnl = decreased position size * (position avg price - current price) / position avg price
    //                       = 500000 * (1 - 1.05) / 1 = -25000 USD
    // new global short pnl = global short pnl - position relaized pnl
    //                     = -50000.000000000000000000000000787301 - (-25000)
    //                     = -25000.000000000000000000000000787301 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 500000 / 1000000 = 500000
    // new global short size = 1000000 USD (global short size - decreased position size)
    // new short average price (global) = current price * new global short size / new global short size - new global long pnl
    //                                 = 1.05 * 1000000 / (1000000 - (-25000.000000000000000000000000787301))
    //                                 = 1.024390243902439024390243902438 USD
    // token profit amount = 0
    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // profit
      tpToken: _tpToken,
      profitAmount: 0,
      // position info
      decreasedPositionSize: 500_000 * 1e30,
      reserveValueDelta: 45_000 * 1e30,
      openInterestDelta: 500_000 * 1e18,
      // average prices
      newPositionAveragePrice: 1 * 1e30,
      newLongGlobalAveragePrice: 0,
      newShortGlobalAveragePrice: 1.024390243902439024390243902438 * 1e30
    });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // fully decrease long position
  // settle loss on long position
  function testCorrectness_WhenTraderFullyDecreaseLongPositionSizeWithLoss() external {
    // Prepare for this test

    // ALICE open LONG position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // BOB open LONG position
    // sub account id - 0
    // position size  - 500,000 USD
    // IMR            - 5,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 526,315.789473684210526315 TOKENs
    // average price  - 0.95 USD
    openPosition(BOB, 0, ethMarketIndex, 500_000 * 1e30);

    // recalculate new long average price after BOB open position
    // global long pnl = global long size * (current price - global avg price) / global avg price
    //                 = 1000000 * (0.95 - 1) / 1 = -50000 USD
    // new global long size = 15000000 (global size + BOB position size)
    // new average long price = new global size * current price / new global size with pnl
    //                        = 1500000 * 0.95 / 1500000 + (-50000) = 0.982758620689655172413793103448 USD
    // THEN MARKET state
    // long position size - 1,500,000 USD
    // open interest       - 1,526,315.789473684210526315 TOKENs
    // average price       - 0.982758620689655172413793103448 USD

    // Start test

    // in this case trader has loss, then we don't care about take profit token
    address _tpToken = address(0);

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // ALICE decrease position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, _tpToken);

    // recalculate long average price after ALICE decrease position
    // global long pnl = global long size * (current price - global avg price) / global avg price
    //                 = 1500000 * (0.95 - 0.982758620689655172413793103448) / 0.982758620689655172413793103448
    //                 = -49999.999999999999999999999999592983 USD
    // position realized pnl = decreased position size * (current price - position avg price) / position avg price
    //                       = 1000000 * (0.95 - 1) / 1 = -50000 USD
    // new global long pnl = global long pnl - position relaized pnl
    //                     = -49999.999999999999999999999999592983 - (-50000)
    //                     = +0.00000000000000000000000040701 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 1000000 / 1000000 = 1000000
    // new global long size = 500000 USD (global long size - decreased position size)
    // new long average price (global) = current price * new global long size / new global long size + new global long pnl
    //                                 = 0.95 * 500000 / (500000 + (+0.000000000000000000000000407018))
    //                                 = 0.949999999999999999999999999999 USD (precision loss)
    // token profit amount = 0
    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // profit
      tpToken: _tpToken,
      profitAmount: 0,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      openInterestDelta: 1_000_000 * 1e18,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 0.949999999999999999999999999999 * 1e30,
      newShortGlobalAveragePrice: 0
    });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // fully decrease short position
  // settle profit on short position
  function testCorrectness_WhenTraderFullyDecreaseShortPositionSizeWithProfit() external {
    // Prepare for this test

    // ALICE open SHORT position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // BOB open SHORT position
    // sub account id - 0
    // position size  - 500,000 USD
    // IMR            - 5,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 526,315.789473684210526315 TOKENs
    // average price  - 0.95 USD
    openPosition(BOB, 0, ethMarketIndex, -500_000 * 1e30);

    // recalculate new short average price after BOB open position
    // global short pnl = global short size * (current price - global avg price) / global avg price
    //                 = 1000000 * (0.95 - 1) / 1 = -50000 USD
    // new global short size = 15000000 (global size + BOB position size)
    // new average short price = new global size * current price / new global size with pnl
    //                        = 1500000 * 0.95 / 1500000 + (-50000) = 0.982758620689655172413793103448 USD
    // THEN MARKET state
    // short position size - 1,500,000 USD
    // open interest       - 1,526,315.789473684210526315 TOKENs
    // average price       - 0.982758620689655172413793103448 USD

    // Start test

    address _tpToken = address(weth); // take profit token

    // let position tester watch this position
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // ALICE decrease position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, _tpToken);

    // recalculate short average price after ALICE decrease position
    // global short pnl = global short size * (global avg price - current price) / global avg price
    //                 = 1500000 * (0.982758620689655172413793103448 - 0.95) / 0.982758620689655172413793103448
    //                 = +49999.999999999999999999999999592983 USD
    // position realized pnl = decreased position size * (position avg price - current price) / position avg price
    //                       = 1000000 * (1 - 0.95) / 1 = +50000 USD
    // new global short pnl = global short pnl - position relaized pnl
    //                     = +49999.999999999999999999999999592983 - (+50000)
    //                     = -0.00000000000000000000000040701 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 1000000 / 1000000 = 1000000
    // new global short size = 500000 USD (global short size - decreased position size)
    // new short average price (global) = current price * new global short size / new global short size - new global long pnl
    //                                 = 0.95 * 500000 / (500000 - (-0.000000000000000000000000407018))
    //                                 = 0.949999999999999999999999999999 USD
    // token profit amount = position realized pnl / price
    //                     = +50000 / 0.95 = 52631.578947368421052631 ether
    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // profit
      tpToken: _tpToken,
      profitAmount: 52631.578947368421052631 ether,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      openInterestDelta: 1_000_000 * 1e18,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 0,
      newShortGlobalAveragePrice: 0.949999999999999999999999999999 * 1e30
    });
    positionTester.assertDecreasePositionResult(_assertData);
  }

  // try decrease long position which already closed
  function testRevert_WhenTraderDecreaseLongPositionWhichAlreadyClosed() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(weth));

    // ALICE try to decrease again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(weth));
  }

  // try decrease short position which already closed
  function testRevert_WhenTraderDecreaseShortPositionWhichAlreadyClosed() external {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    // ALICE close all position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(weth));

    // ALICE try to decrease again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(weth));
  }

  // decrease too much long position
  function testRevert_WhenTraderDecreaseTooMuchLongPositionSize() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_DecreaseTooHighPositionSize()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30, address(weth));
  }

  // decrease too much short position
  function testRevert_WhenTraderDecreaseTooMuchShortPositionSize() external {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_DecreaseTooHighPositionSize()"));
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_001 * 1e30, address(weth));
  }

  // position remain too tiny size after decrease long position
  function testRevert_AfterDecreaseLongPositionAndRemainPositionSizeIsTooTiny() external {
    // ALICE open LONG position
    openPosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30);
    vm.expectRevert(abi.encodeWithSignature("ITradeService_TooTinyPosition()"));
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29, address(weth));
  }

  // position remain too tiny size after decrease short position
  function testRevert_AfterDecreaseShortPositioAndRemainPositionSizeIsTooTiny() external {
    // ALICE open SHORT position
    openPosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30);
    vm.expectRevert(abi.encodeWithSignature("ITradeService_TooTinyPosition()"));
    // decrease position for 999,999.9
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 9_999_999 * 1e29, address(weth));
  }

  // note: this case need to open many position and then decrease 1 with a lot of loss size
  //       now we still not support about settle profit and loss todo: make this test valid
  //       may can move this to complex test case
  // function testRevert_AfterPositionDecreasedAndSubAccountEquityIsLessThanMMR()
  //   external
  // {}
}
