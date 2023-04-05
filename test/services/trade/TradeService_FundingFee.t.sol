// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

contract TradeService_FundingFee is TradeService_Base {
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
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getNextFundingRate");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getFundingFee");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
      tradeHelper.reloadConfig();
    }

    // Set PLPLiquidity
    vaultStorage.addPLPLiquidity(configStorage.getPlpTokens()[0], 1000 * 1e18);

    // Ignore Borrowing fee on this test
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRate: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // Ignore Developer fee on this test
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 5 })
    );

    // Set funding rate config
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.fundingRate.maxFundingRate = 0.0004 * 1e18;
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
    vaultStorage.increaseTraderBalance(aliceAddress, address(weth), 1 * 1e18);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 1_000 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

      assertEq(_assetClass.sumBorrowingRate, 0);
      assertEq(_assetClass.lastBorrowingTime, 100);

      assertEq(_market.currentFundingRate, 0);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 1_000 * 1e6);

      assertEq(vaultStorage.devFees(address(weth)), 0);
      assertEq(vaultStorage.fundingFeeReserve(address(weth)), 10 * 1e18); // Initial funding fee WETH = 10 WETH
    }

    vm.warp(block.timestamp + 1);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      {
        IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);

        // Repay WETH Amount = 133.333333333333/1600 = 0.083333333333333125 WETH
        // Dev fee = 0.083333333333333125  * 0 = 0 WETH
        assertEq(vaultStorage.devFees(address(weth)), 0, "Dev fee");

        // After Alice pay fee, Alice's WETH amount will be decreased
        // Alice's WETH remaining = 1 - 0.083333333333333125 = 0.916666666666666875 WETH
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 916666666666666875, "Weth balance");

        // new fundingFee = old fundingFee + (fee collect from ALICE - dev Fee) = 10 + ( 0.08383958333333312 - 0) = 10.0838395833 WETH
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), (10 + 0.083333333333333125) * 1e18);
      }
    }
  }

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
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 1_000 * 1e6);
    vaultStorage.increaseTraderBalance(bobAddress, address(usdt), 500 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);
      assertEq(_market.currentFundingRate, 0);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 1_000 * 1e6);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 500 * 1e6);
    }

    vm.warp(block.timestamp + 1);
    {
      tradeService.increasePosition(BOB, 0, ethMarketIndex, -200_000 * 1e30, 0);
      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);
      IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
      assertEq(_market.currentFundingRate, -66666666666666); // LONG PAY SHORT
      // Alice increase long position size * funding Rate = 500_000 * -0.000066666666666666 = -33.333333333333 $

      assertEq(vaultStorage.fundingFeeReserve(address(usdt)), 0);
    }

    // Simulate BOB close Short position, BOB should receive funding fee
    vm.warp(block.timestamp + 1);
    {
      assertEq(vaultStorage.traderBalances(bobAddress, address(weth)), 0);
      assertEq(vaultStorage.plpLiquidityDebtUSDE30(), 0);

      tradeService.decreasePosition(BOB, 0, ethMarketIndex, 200_000 * 1e30, address(0), 0);
      IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(0);
      assertEq(_market.currentFundingRate, -106666666666666); // LONG PAY SHORT

      // After BOB close short position, BOB must get funding fee
      assertEq(vaultStorage.fundingFeeReserve(address(usdt)), 0);
      assertEq(vaultStorage.traderBalances(bobAddress, address(weth)), 5333333333333333); // 0.005333333333333333 ETH
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 500 * 1e6);
    }
  }
}
