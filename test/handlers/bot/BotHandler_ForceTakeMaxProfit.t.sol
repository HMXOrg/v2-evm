// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

/// @title BotHandler_ForceTakeMaxProfit
/// @notice The purpose is test BotHandler contract able to call TradeService to force close position of trader
///         And take maximum of profit (reserved value of position)
contract BotHandler_ForceTakeMaxProfit is BotHandler_Base {
  // What this test DONE
  // note: random correctness / revert cases from TradeService_ForceClosePosition
  // - correctness
  //   - close and take profit when profit = reserved value
  //   - close and take profit when profit > reserved value
  // revert
  //   - price stale
  //   - try close long position which already closed
  //   - unauthorized (owned test)
  function setUp() public virtual override {
    super.setUp();

    // Override the mock calculator
    {
      mockCalculator = new MockCalculatorWithRealCalculator(
        address(mockOracle),
        address(vaultStorage),
        address(perpStorage),
        address(configStorage)
      );
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("calculateLongAveragePrice");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("calculateShortAveragePrice");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getDelta");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
    }

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
    vaultStorage.setTraderBalance(_getSubAccount(ALICE, 0), address(weth), 100_000 ether);
  }

  /**
   * Revert
   */

  function testRevert_WhenSomeoneCallBotHandler() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
    botHandler.forceTakeMaxProfit(ALICE, 0, ethMarketIndex, address(0), prices);
  }

  /**
   * Copied test from TradeService_ForceClosePosition
   */

  // ref: testCorrectness_WhenExecutorCloseShortPositionForAlice_AndProfitIsGreaterThenReserved
  function testCorrectness_WhenBotHandlerForceTakeMaxProfit_AndProfitIsGreaterThenReserved() external {
    // Prepare for this test

    // ALICE open SHORT position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);

    // price change to 0.95 USD
    mockOracle.setPrice(0.95 * 1e30);

    // BOB open SHORT position
    tradeService.increasePosition(BOB, 0, ethMarketIndex, -500_000 * 1e30, 0);

    address _tpToken = address(weth); // take profit token

    // let position tester watch this position
    bytes32 _positionId = _getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // price changed to 0.9 USD
    mockOracle.setPrice(0.9 * 1e30);

    // Bot force take max profit ALICE position
    botHandler.forceTakeMaxProfit(ALICE, 0, ethMarketIndex, _tpToken, prices);

    // all calculation is same with testCorrectness_WhenExecutorCloseShortPositionForAlice_AndProfitIsGreaterThenReserved
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

  // ref: testCorrectness_WhenExecutorCloseLongPositionForAlice_AndProfitIsEqualsToReserved
  function testCorrectness_WhenBotHandlerForceTakeMaxProfit_AndProfitIsEqualsToReserved() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // price change to 1.05 USD
    mockOracle.setPrice(1.05 * 1e30);

    // BOB open LONG position
    tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

    address _tpToken = address(weth); // take profit token

    // let position tester watch this position
    bytes32 _positionId = _getPositionId(ALICE, 0, ethMarketIndex);
    positionTester.watch(ALICE, 0, _tpToken, _positionId);

    // price change to 1.09 USD
    mockOracle.setPrice(1.09 * 1e30);

    // Tester close ALICE position
    botHandler.forceTakeMaxProfit(ALICE, 0, ethMarketIndex, _tpToken, prices);

    // all calculation is same with testCorrectness_WhenExecutorCloseLongPositionForAlice_AndProfitIsEqualsToReserved
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

  // ref: testRevert_WhenExecutorTryClosePositionButPriceStale
  function testRevert_WhenBotHandlerForceTakeMaxProfitButPriceStale() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // make price stale in mock oracle middleware
    mockOracle.setPriceStale(true);

    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    botHandler.forceTakeMaxProfit(ALICE, 0, ethMarketIndex, address(0));
  }

  // ref: testRevert_WhenExecutorTryCloseLongPositionButPositionIsAlreadyClosed
  function testRevert_WhenBotHandlerForceTakeMaxProfitButPositionIsAlreadyClosed() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // ALICE fully close position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);

    // Somehow Tester close ALICE position again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    botHandler.forceTakeMaxProfit(ALICE, 0, ethMarketIndex, address(0), prices);
  }
}
