// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

// What is this test DONE
// - success
//   - can close posiiton when plp not healthy
// - revert
//   - when plp healthy
//   - market delisted
//   - market status from oracle is inactive (market close)
//   - over deleverage

contract TradeService_Deleverage is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevert_deleverage_WhenPlpHealthy() external {
    // Add Liquidity 120,000 USDT -> 120,000 USD
    // TVL = 120,000 USD
    // AUM = 120,000 USD
    vaultStorage.addPLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setPLPValue(120_000 * 1e30);
    mockCalculator.setAUM(120_000 * 1e30);

    // ALICE add collateral 10,000 USD
    // Free collateral 10,000 USD
    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1,500 USD
    mockOracle.setPrice(wethAssetId, 1_500 * 1e30);

    // ALICE open position Long ETH 1,000,000
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // ETH price 1,560 USD
    mockOracle.setPrice(wethAssetId, 1_560 * 1e30);

    // ALICE's position profit 40,000 USD
    // AUM = 120,000 - 40,000 = 80,000
    mockCalculator.setAUM((80_000) * 1e30);

    // PLP safety buffer = 1 + ((80,000 - 120,000) / 120,000) = 0.6666666666666667
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PlpHealthy()"));
    tradeService.deleverage(ALICE, 0, ethMarketIndex, address(usdt));
  }

  function testRevert_deleverage_WhenMarketIsDelisted() external {
    vaultStorage.addPLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setPLPValue(120_000 * 1e30);
    mockCalculator.setAUM(120_000 * 1e30);

    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    mockOracle.setPrice(wethAssetId, 1_500 * 1e30);
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    mockOracle.setPrice(wethAssetId, 1_620 * 1e30);
    mockCalculator.setAUM((40_000) * 1e30);

    // someone delist market
    configStorage.delistMarket(ethMarketIndex);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsDelisted()"));
    tradeService.deleverage(ALICE, 0, ethMarketIndex, address(usdt));
  }

  function testRevert_deleverage_WhenMarketIsClosed() external {
    vaultStorage.addPLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setPLPValue(120_000 * 1e30);
    mockCalculator.setAUM(120_000 * 1e30);

    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    mockOracle.setPrice(wethAssetId, 1_500 * 1e30);
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    mockOracle.setPrice(wethAssetId, 1_620 * 1e30);
    mockCalculator.setAUM((40_000) * 1e30);

    // set market status from oracle is inactive
    mockOracle.setMarketStatus(1);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketIsClosed()"));
    tradeService.deleverage(ALICE, 0, ethMarketIndex, address(usdt));
  }

  function testCorrectness_deleverage() external {
    // Add Liquidity 120,000 USDT -> 120,000 USD
    // TVL = 120,000 USD
    // AUM = 120,000 USD
    vaultStorage.addPLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setPLPValue(120_000 * 1e30);
    mockCalculator.setAUM(120_000 * 1e30);

    // ALICE add collateral 10,000 USD
    // Free collateral 10,000 USD
    mockCalculator.setEquity(ALICE, 10_000 * 1e30);
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1,500 USD
    mockOracle.setPrice(wethAssetId, 1_500 * 1e30);

    // ALICE open position Long ETH 1,000,000
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

    // ETH price 1,620 USD
    mockOracle.setPrice(wethAssetId, 1_620 * 1e30);

    // ALICE's position profit 80,000 USD
    // AUM = 120,000 - 80,000 = 40,000
    mockCalculator.setAUM((40_000) * 1e30);

    // PLP safety buffer = 1 + ((40,000 - 120,000) / 120,000) = 0.33333333333333337
    tradeService.deleverage(ALICE, 0, ethMarketIndex, address(usdt));
  }

  function testRevert_deleverage_WhenOverDeleverage() external {
    // Add Liquidity 120,000 USDT -> 120,000 USD
    // TVL = 160,000 USD
    // AUM = 160,000 USD
    vaultStorage.addPLPLiquidity(address(usdt), 160_000 * 1e6);
    mockCalculator.setPLPValue(160_000 * 1e30);
    mockCalculator.setAUM(160_000 * 1e30);

    // ALICE add collateral 20,000 USD
    // Free collateral 20,000 USD
    mockCalculator.setEquity(ALICE, 20_000 * 1e30);
    mockCalculator.setFreeCollateral(20_000 * 1e30);

    // ETH price 1,500 USD
    mockOracle.setPrice(wethAssetId, 1_500 * 1e30);
    // BTC price 25,000 USD
    mockOracle.setPrice(wbtcAssetId, 25_000 * 1e30);

    // ALICE open position Long ETH 1,000,000
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
    // ALICE open position Long BTC 1,000,000
    tradeService.increasePosition(ALICE, 0, btcMarketIndex, 400_000 * 1e30, 0);

    // ETH price 1,620 USD
    mockOracle.setPrice(wethAssetId, 1_620 * 1e30);

    // ALICE's position profit 80,000 USD
    // AUM = 160,000 - 80,000 = 80,000
    mockCalculator.setAUM((80_000) * 1e30);

    // PLP safety buffer = 1 + ((80,000 - 160,000) / 160,000) = 0.5
    tradeService.deleverage(ALICE, 0, ethMarketIndex, address(usdt));
    // After deleverage settle profit to ALICE
    // TVL = 160,000 - 80,000 = 80,000
    mockCalculator.setPLPValue(80_000 * 1e30);

    // PLP safety buffer = 1 + ((80,000 - 80,000) / 80,000) = 1
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PlpHealthy()"));
    tradeService.deleverage(ALICE, 0, btcMarketIndex, address(usdt));
  }
}
