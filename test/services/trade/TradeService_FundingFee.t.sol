// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { MockCalculatorWithRealGetNextFundingRate } from "../../mocks/MockCalculatorWithRealGetNextFundingRate.sol";

contract TradeService_FundingFee is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();
    mockCalculator = new MockCalculatorWithRealGetNextFundingRate(
      address(mockOracle),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );
    configStorage.setCalculator(address(mockCalculator));

    // Set PLPLiquidity
    vaultStorage.addPLPLiquidity(configStorage.getPlpTokens()[0], 1000 * 1e18);

    // Ignore Borrowing fee on this test
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRateBPS: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // Ignore Developer fee on this test
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 5 })
    );

    // Set funding rate config
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.fundingRate.maxFundingRateBPS = 0.0004 * 1e4;
    _marketConfig.fundingRate.maxSkewScaleUSD = 3_000_000 * 1e30;

    configStorage.setMarketConfig(ethMarketIndex, _marketConfig);
  }

  function testCorrectness_fundingFee() external {
    // Set fundingFee to have enough token amounts to repay funding fee
    vaultStorage.addFundingFee(configStorage.getPlpTokens()[0], 10 * 1e18);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1 USD
    mockOracle.setPrice(1600 * 1e30);
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.setTraderBalance(aliceAddress, address(weth), 1 * 1e18);
    vaultStorage.setTraderBalance(aliceAddress, address(usdt), 1_000 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
      IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);

      assertEq(_globalAssetClass.sumBorrowingRate, 0);
      assertEq(_globalAssetClass.lastBorrowingTime, 100);

      assertEq(_globalMarket.currentFundingRate, 0);
      assertEq(_globalMarket.accumFundingLong, 0);
      assertEq(_globalMarket.accumFundingShort, 0);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 1_000 * 1e6);

      assertEq(vaultStorage.devFees(address(weth)), 0);
      assertEq(vaultStorage.fundingFee(address(weth)), 10 * 1e18); // Initial margin fee WETH = 10 WETH
    }

    vm.warp(block.timestamp + 1);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      {
        IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
        IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);

        // Long position now must pay 133$ to Short Side
        assertEq(_globalMarket.accumFundingLong, -133333333333333000000); // -133.33$
        assertEq(_globalMarket.accumFundingShort, 0); //

        // Repay WETH Amount = 133.33/1600 = 0.08383958333333312 WETH
        // Dev fee = 0.08383958333333312  * 0 = 0 WETH
        assertEq(vaultStorage.devFees(address(weth)), 0, "Dev fee");

        // After Alice pay fee, Alice's WETH amount will be decreased
        // Alice's WETH remaining = 1 - 0.08383958333333312 = 0.916666666666666875 WETH
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 916666666666666875, "Weth balance");

        // Alice already paid all fees
        assertEq(perpStorage.getSubAccountFee(aliceAddress), 0, "Subaccount fee");

        // new fundingFee = old fundingFee + (fee collect from ALICE - dev Fee) = 10 + ( 0.08383958333333312 - 0) = 10083333333333333125 WETH
        assertEq(vaultStorage.fundingFee(address(weth)), 10083333333333333125, "Funding fee");
      }
    }
  }

  // TODO: work on this
  function testCorrectness_fundingFee_borrowFundingFeeFromPLP() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1500 USD
    mockOracle.setPrice(1500 * 1e30);
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    address bobAddress = getSubAccount(BOB, 0);
    // Set Alice collateral balance
    vaultStorage.setTraderBalance(aliceAddress, address(usdt), 1_000 * 1e6);
    vaultStorage.setTraderBalance(bobAddress, address(usdt), 500 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);
      assertEq(_globalMarket.currentFundingRate, 0);
      assertEq(_globalMarket.accumFundingLong, 0);
      assertEq(_globalMarket.accumFundingShort, 0);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 1_000 * 1e6);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 500 * 1e6);
    }

    vm.warp(block.timestamp + 1);
    {
      tradeService.increasePosition(BOB, 0, ethMarketIndex, -200_000 * 1e30, 0);
      IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);
      assertEq(_globalMarket.currentFundingRate, -66666666666666); // LONG PAY SHORT
      // Alice increase long position size * funding Rate = 500_000 * -0.000066666666666666 = -33.333333333333 $
      assertEq(_globalMarket.accumFundingLong, -33333333333333000000);
      assertEq(_globalMarket.accumFundingShort, 0);

      assertEq(vaultStorage.fundingFee(address(usdt)), 0);
    }

    // Simulate BOB close Short position, BOB should receive funding fee
    vm.warp(block.timestamp + 1);
    {
      assertEq(vaultStorage.traderBalances(bobAddress, address(weth)), 0);
      assertEq(vaultStorage.plpLiquidityDebtUSDE30(), 0);

      tradeService.decreasePosition(BOB, 0, ethMarketIndex, 200_000 * 1e30, address(0), 0);
      IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);
      assertEq(_globalMarket.currentFundingRate, -106666666666666); // LONG PAY SHORT
      // Alice increase long position size * funding Rate * elapsedInterval = (500_000 * -0.000106666666666666) + last accumFundingLong = -53.333333333333 + -33.333333333333 = -86.666666666666$
      assertEq(_globalMarket.accumFundingLong, -86666666666666000000);
      assertEq(_globalMarket.accumFundingShort, 21333333333333200000);

      // After BOB close short position, BOB must get funding fee
      assertEq(vaultStorage.fundingFee(address(usdt)), 0);
      assertEq(vaultStorage.plpLiquidityDebtUSDE30(), 8000000000000000000000000000000); // 8$
      assertEq(vaultStorage.traderBalances(bobAddress, address(weth)), 5333333333333333); // 0.005333333333333333 ETH
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 500 * 1e6);
    }
  }
}
