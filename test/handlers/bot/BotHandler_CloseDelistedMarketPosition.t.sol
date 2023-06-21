// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BotHandler_Base } from "./BotHandler_Base.t.sol";

import { PositionTester } from "../../testers/PositionTester.sol";
import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

/// @title BotHandler_CloseDelistedMarketPosition
/// @notice The purpose is test BotHandler contract able to call TradeService to force close position of trader
///         And take maximum of profit (reserved value of position)
contract BotHandler_CloseDelistedMarketPosition is BotHandler_Base {
  // What this test DONE
  // note: random correctness / revert cases from TradeService_z
  // - correctness
  //   - close and take profit
  //   - close and take profit
  // revert
  //   - price stale
  //   - try close long position which already closed
  //   - unauthorized (owned test)
  function setUp() public virtual override {
    super.setUp();

    // Override the mock calculator
    {
      mockCalculator = new MockCalculatorWithRealCalculator(
        address(proxyAdmin),
        address(mockOracle),
        address(vaultStorage),
        address(perpStorage),
        address(configStorage)
      );
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("calculateMarketAveragePrice");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getDelta");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getLatestPrice");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
    }

    // TVL
    // 1000000 USDT -> 2000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);

    // assume ALICE has free collateral for 10,000 USD
    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // mock HLP token for profitable trader
    // related with TVL 2,000,000 USD then provide liquidity, - 1,000,000 WETH (price 1$)
    //                                                        - 10,000 WBTC (price 100$)
    vaultStorage.addHLPLiquidity(address(weth), 1_000_000 ether);
    vaultStorage.addHLPLiquidity(address(wbtc), 10_000 ether);

    // assume ALICE sub-account 0 has collateral
    // weth - 100,000 ether
    vaultStorage.increaseTraderBalance(_getSubAccount(ALICE, 0), address(weth), 100_000 ether);
  }

  /**
   * Revert
   */

  function testRevert_WhenSomeoneCallBotHandler() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      address(0),
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );
  }

  /**
   * Copied test from TradeService_ForceClosePosition
   */

  // ref: testCorrectness_WhenExecutorCloseShortPositionForAlice_AndProfitIsGreaterThenReserved
  function testCorrectness_closeDelistedMarketPosition_AndProfitIsGreaterThenReserved() external {
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

    configStorage.delistMarket(ethMarketIndex);

    // Bot force take max profit ALICE position
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      _tpToken,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    // all calculation is same with testCorrectness_WhenExecutorCloseShortPositionForAlice_AndProfitIsGreaterThenReserved
    address[] memory _checkHlpTokens = new address[](1);
    uint256[] memory _expectedTraderBalances = new uint256[](1);
    uint256[] memory _expectedHlpLiquidities = new uint256[](1);
    uint256[] memory _expectedFees = new uint256[](1);

    _checkHlpTokens[0] = _tpToken;
    _expectedTraderBalances[0] = 199_500 ether;
    _expectedHlpLiquidities[0] = 900_000 ether;
    _expectedFees[0] = 500 ether;

    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      // realizedPnl: 90_000 * 1e30,
      realizedPnl: 0,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 0,
      newShortGlobalAveragePrice: 0.970488081725312145289443813847 * 1e30
    });
    positionTester.assertDecreasePositionResult(
      _assertData,
      _checkHlpTokens,
      _expectedTraderBalances,
      _expectedHlpLiquidities,
      _expectedFees
    );
  }

  // ref: testCorrectness_WhenExecutorCloseLongPositionForAlice_AndProfitIsEqualsToReserved
  function testCorrectness_closeDelistedMarketPosition_AndProfitIsEqualsToReserved() external {
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

    configStorage.delistMarket(ethMarketIndex);

    // Tester close ALICE position
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      _tpToken,
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    // all calculation is same with testCorrectness_WhenExecutorCloseLongPositionForAlice_AndProfitIsEqualsToReserved
    address[] memory _checkHlpTokens = new address[](1);
    uint256[] memory _expectedTraderBalances = new uint256[](1);
    uint256[] memory _expectedHlpLiquidities = new uint256[](1);
    uint256[] memory _expectedFees = new uint256[](1);

    _checkHlpTokens[0] = _tpToken;
    _expectedTraderBalances[0] = 182_155.963302752293577981 ether;
    _expectedHlpLiquidities[0] = 917_431.192660550458715597 ether;
    _expectedFees[0] = 412.844036697247706422 ether;

    PositionTester.DecreasePositionAssertionData memory _assertData = PositionTester.DecreasePositionAssertionData({
      primaryAccount: ALICE,
      subAccountId: 0,
      // position info
      decreasedPositionSize: 1_000_000 * 1e30,
      reserveValueDelta: 90_000 * 1e30,
      // realizedPnl: 90_000 * 1e30,
      realizedPnl: 0,
      // average prices
      newPositionAveragePrice: 0,
      newLongGlobalAveragePrice: 1.049999999999999999999999999998 * 1e30,
      newShortGlobalAveragePrice: 0
    });
    positionTester.assertDecreasePositionResult(
      _assertData,
      _checkHlpTokens,
      _expectedTraderBalances,
      _expectedHlpLiquidities,
      _expectedFees
    );
  }

  // ref: testRevert_WhenExecutorTryClosePositionButPriceStale
  function testRevert_closeDelistedMarketPosition_ButPriceStale() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    configStorage.delistMarket(ethMarketIndex);

    // make price stale in mock oracle middleware
    mockOracle.setPriceStale(true);

    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      address(0),
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );
  }

  // ref: testRevert_WhenExecutorTryCloseLongPositionButPositionIsAlreadyClosed
  function testRevert_closeDelistedMarketPosition_ButPositionIsAlreadyClosed() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // ALICE fully close position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);

    configStorage.delistMarket(ethMarketIndex);

    // Somehow Tester close ALICE position again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionAlreadyClosed()"));
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      address(0),
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );
  }

  function testRevert_closeDelistedMarketPosition_ButMarketHealthy() external {
    // ALICE open LONG position
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // ALICE fully close position
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, address(0), 0);

    // Somehow Tester close ALICE position again
    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketHealthy()"));
    botHandler.closeDelistedMarketPosition(
      ALICE,
      0,
      ethMarketIndex,
      address(0),
      priceUpdateData,
      publishTimeUpdateData,
      block.timestamp,
      keccak256("someEncodedVaas")
    );
  }
}
