// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester } from "../../testers/PositionTester.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";

// What is this test DONE
// - success
//   - close and take profit when profit = reserved value
//   - close and take profit when profit > reserved value
// - revert
//   - try close position when position loss
//   - try close position when position profit but < reserved value
//   - market delisted
//   - market status from oracle is inactive (market close)
//   - price stale
//   - try close long position which already closed
//   - try close short position which already closed
// - misc
//   - settle profit & loss with settlement fee
//   - pull multiple tokens from user when loss
// What is this test not covered
//   - borrowing fee
//   - funding fee
//   - trading fee
//   - protocol curcuit break
//   - trading curcuit break

contract TradeService_ForceClosePosition is TradeService_Base {
  using AddressUtils for address;

  function setUp() public virtual override {
    super.setUp();

    // TVL
    // 1000000 USDT -> 2000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);

    // assume ALICE has free collateral for 10,000 USD
    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // mock PLP token for profitable trader
    // related with TVL 2,000,000 USD then provide liquidity, - 1,000,000 WETH (price 1$)
    //                                                        - 10,000 WBTC (price 100$)
    vaultStorage.addPLPLiquidity(address(weth), 1_000_000 ether);
    vaultStorage.addPLPLiquidity(address(wbtc), 10_000 ether);

    // assume ALICE sub-account 0 has collateral
    // weth - 100,000 ether
    vaultStorage.setTraderBalance(getSubAccount(ALICE, 0), address(weth), 100_000 ether);
  }

  /**
   * Correctness
   */

  function testCorrectness_WhenExecutorCloseShortPositionForAlice_AndProfitIsGreaterThenReserved() external {
    // Prepare for this test

    // open SHORT position for ALICE
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);

    // price change to 0.95 USD
    // to check open interest should calculate correctly
    mockOracle.setPrice(0.95 * 1e30);

    // open SHORT position for BOB
    // sub account id - 0
    // position size  - 500,000 USD
    // IMR            - 5,000 USD (1% IMF)
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 526,315.789473684210526315 TOKENs
    // average price  - 0.95 USD
    tradeService.increasePosition(BOB, 0, ethMarketIndex, -500_000 * 1e30, 0);

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

    // price changed to 0.9 USD
    mockOracle.setPrice(0.9 * 1e30);

    // Tester close ALICE position
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, _tpToken);

    // recalculate short average price after ALICE decrease position
    // global short pnl = global short size * (global avg price - current price) / global avg price
    //                 = 1500000 * (0.982758620689655172413793103448 - 0.9) / 0.982758620689655172413793103448
    //                 = +126315.789473684210526315789473298614 USD
    // position realized pnl = decreased position size * (position avg price - current price) / position avg price
    //                       = 1000000 * (1 - 0.9) / 1 = +100000 USD (reserved value is 90000)
    // then actual realized profit = +90000
    // new global short pnl = global short pnl - position relaized pnl
    //                     = +126315.789473684210526315789473298614 - (+90000)
    //                     = +36315.789473684210526315789473298614 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 1000000 / 1000000 = 1000000
    // new global short size = 500000 USD (global short size - decreased position size)
    // new short average price (global) = current price * new global short size / new global short size - new global long pnl
    //                                 = 0.9 * 500000 / (500000 - (+36315.789473684210526315789473298614))
    //                                 = 0.970488081725312145289443813847 USD
    // ALICE position has profit 90000 USD
    // ALICE sub account 0 has WETH as collateral = 100,000 ether
    // profit in WETH = 90000 / 0.9 = 100000 ether
    // settlement fee rate 0.5% note: from mock
    // settlement fee = 100000 * 0.5 / 100 = 500 ether
    // then ALICE sub account 0 collateral should be increased by 100000 - 500 = 99500 ether
    //                             = 100000 + 99500 = 199500 ether
    // and PLP WETH liquidity should reduced by 100000 ether
    //     PLP WETH liquidity has 1,000,000 ether then liquidity remaining is 1000000 - 100000 = 900000 ether
    // finally fee should increased by 500 ether
    address[] memory _checkPlpTokens = new address[](1);
    uint256[] memory _expectedTraderBalances = new uint256[](1);
    uint256[] memory _expectedPlpLiquidities = new uint256[](1);
    uint256[] memory _expectedFees = new uint256[](1);

    _checkPlpTokens[0] = _tpToken;
    _expectedTraderBalances[0] = 199_500 ether;
    _expectedPlpLiquidities[0] = 900_000 ether;
    _expectedFees[0] = 500 ether;

    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      openInterestDelta: 1_000_000 * 1e18,
      realizedPnl: 90_000 * 1e30,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 0,
      newShortGlobalAveragePrice: 0.970488081725312145289443813847 * 1e30
    });
    positionTester.assertDecreasePositionResult(
      _assertData,
      _checkPlpTokens,
      _expectedTraderBalances,
      _expectedPlpLiquidities,
      _expectedFees
    );
  }

  function testCorrectness_WhenExecutorCloseLongPositionForAlice_AndProfitIsEqualsToReserved() external {
    // Prepare for this test

    // ALICE open Long position
    // sub account id - 0
    // position size  - 1,000,000 USD
    // IMR            - 10,000 USD (1% IMF)
    // Reserved       - 90,000 USD
    // leverage       - 100x
    // price          - 1 USD
    // open interest  - 1,000,000 TOKENs
    // average price  - 1 USD
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

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
    tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

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

    // price change to 1.09 USD
    mockOracle.setPrice(1.09 * 1e30);

    // Tester close ALICE position
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, _tpToken);

    // recalculate long average price after ALICE decrease position
    // global long pnl = global long size * (current price - global avg price) / global avg price
    //                 = 1500000 * (1.09 - 1.016129032258064516129032258064) / 1.016129032258064516129032258064
    //                 = +109047.619047619047619047619048436341 USD
    // position realized pnl = decreased position size * (current price - position avg price) / position avg price
    //                       = 1000000 * (1.09 - 1) / 1 = +90000 USD (but reserved value for this position is 90000)
    // new global long pnl = global long pnl - position relaized pnl
    //                     = +109047.619047619047619047619048436341 - (+90000)
    //                     = +19047.619047619047619047619048436341 USD
    // open interest delta = position open interest * position size to decrease / position size
    //                     = 1000000 * 1000000 / 1000000 = 1000000
    // new global long size = 500000 USD (global long size - decreased position size)
    // new long average price (global) = current price * new global long size / new global long size + new global long pnl
    //                                 = 1.09 * 500000 / (500000 + (+19047.619047619047619047619048436341))
    //                                 = 1.049999999999999999999999999999 USD
    // ALICE position has profit 90000 USD
    // ALICE sub account 0 has WETH as collateral = 100,000 ether
    // profit in WETH = 90000 / 1.09 = 82568.807339449541284403 ether
    // settlement fee rate 0.5% note: from mock
    // settlement fee = 82568.807339449541284403 * 0.5 / 100 = 412.844036697247706422 ether
    // then ALICE sub account 0 collateral should be increased by 82568.807339449541284403 - 412.844036697247706422 = 82155.963302752293577981 ether
    //                             = 100000 + 82155.963302752293577981 = 182155.963302752293577981 ether
    // and PLP WETH liquidity should reduced by 82568.807339449541284403 ether
    //     PLP WETH liquidity has 1,000,000 ether then liquidity remaining is 1000000 - 82568.807339449541284403 = 917431.192660550458715597 ether
    // finally fee should increased by 412.844036697247706422 ether
    address[] memory _checkPlpTokens = new address[](1);
    uint256[] memory _expectedTraderBalances = new uint256[](1);
    uint256[] memory _expectedPlpLiquidities = new uint256[](1);
    uint256[] memory _expectedFees = new uint256[](1);

    _checkPlpTokens[0] = _tpToken;
    _expectedTraderBalances[0] = 182_155.963302752293577981 ether;
    _expectedPlpLiquidities[0] = 917_431.192660550458715597 ether;
    _expectedFees[0] = 412.844036697247706422 ether;

    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      openInterestDelta: 1_000_000 * 1e18,
      realizedPnl: 90_000 * 1e30,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 1.049999999999999999999999999998 * 1e30,
      newShortGlobalAveragePrice: 0
    });
    positionTester.assertDecreasePositionResult(
      _assertData,
      _checkPlpTokens,
      _expectedTraderBalances,
      _expectedPlpLiquidities,
      _expectedFees
    );
  }

  /**
   * Revert
   */

  function testRevert_WhenAlicePositionLossingAndExecutorTryToCloseIt() external {
    // ALICE open Long position at price 1 USD
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // price has changed make ALICE position lossing
    mockOracle.setPrice(0.95 * 1e30);

    // Tester try to close ALICE position
    vm.expectRevert(abi.encodeWithSignature("ITradeService_ReservedValueStillEnough()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenAlicePositionHasProfitButStillLessThanReservedValueAndExecutorTryToCloseIt() external {
    // ALICE open Short position  price 1 USD
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // price has changed make ALICE position profit for ~899.9999999999%
    mockOracle.setPrice(0.900000000001 * 1e30);

    // Tester try to close ALICE position
    vm.expectRevert(abi.encodeWithSignature("ITradeService_ReservedValueStillEnough()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenExecutorTryClosePositionButMarketIsDelistedFromPerp() external {
    // ALICE open Long position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // someone delist market
    configStorage.delistMarket(ethMarketIndex);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsDelisted()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenExecutorTryClosePositionButOracleTellMarketIsClose() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // set market status from oracle is inactive
    mockOracle.setMarketStatus(1);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsClosed()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenExecutorTryClosePositionButPriceStale() external {
    // open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // make price stale in mock oracle middleware
    mockOracle.setPriceStale(true);

    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenExecutorTryCloseLongPositionButPositionIsAlreadyClosed() external {
    // open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // fully close position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);

    // Somehow Tester close position again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }

  function testRevert_WhenExecutorTryShortClosePositionButPositionIsAlreadyClosed() external {
    // open SHORT position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);

    // fully close position

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);

    // Somehow Tester close position again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    tradeService.forceClosePosition(ALICE, 0, ethMarketIndex, address(0));
  }
}
