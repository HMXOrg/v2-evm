// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

// What is this test DONE
// - success
//   - validateMarketDelisted when market not delisted
//   - validateDeleverage when hlp not healthy
//   - validateMaxProfit when close with max profit
// - revert
//   - validateMarketDelisted when market delisted
//   - validateDeleverage when hlp healthy
//   - validateMaxProfit when not close with max profit

contract TradeService_Validate_ForceClosePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevert_validateMarketDelisted_WhenMarketHealthy() external {
    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketHealthy()"));
    tradeService.validateMarketDelisted(ethMarketIndex);
  }

  function testRevert_validateDeleverage_WhenHlpHealthy() external {
    // Add Liquidity 120,000 USDT -> 120,000 USD
    // TVL = 120,000 USD
    // AUM = 120,000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setHLPValue(120_000 * 1e30);
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

    // HLP safety buffer = 1 + ((80,000 - 120,000) / 120,000) = 0.6666666666666667
    vm.expectRevert(abi.encodeWithSignature("ITradeService_HlpHealthy()"));
    tradeService.validateDeleverage();
  }

  function testRevert_validateMaxProfit_WhenIsNotMaxProfit() external {
    vm.expectRevert(abi.encodeWithSignature("ITradeService_ReservedValueStillEnough()"));
    tradeService.validateMaxProfit(false);
  }

  function testCorrectness_validateMarketDelisted() external {
    configStorage.delistMarket(ethMarketIndex);

    tradeService.validateMarketDelisted(ethMarketIndex);
  }

  function testCorrectness_validateDeleverage() external {
    // Add Liquidity 120,000 USDT -> 120,000 USD
    // TVL = 120,000 USD
    // AUM = 120,000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 120_000 * 1e6);
    mockCalculator.setHLPValue(120_000 * 1e30);
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

    // HLP safety buffer = 1 + ((40,000 - 120,000) / 120,000) = 0.33333333333333337
    tradeService.validateDeleverage();
  }

  function testRevert_validateMaxProfit() external view {
    tradeService.validateMaxProfit(true);
  }
}
