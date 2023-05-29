// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

// What is this test DONE
// - success
//   - collect fee from increase position
//   - collect fee from decrease position
contract TradeService_BorrowingFee is TradeService_Base {
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
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getBorrowingFee");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getNextBorrowingRate");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getHLPValueE30");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
      tradeHelper.reloadConfig();
    }
  }

  function testCorrectness_borrowingFee_WhenIncreasePosition() external {
    // TVL - make the hlp value
    // 1000000 USDT -> 1000000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 1_000_000 * 1e6);

    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    address bobAddress = getSubAccount(BOB, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      assertEq(_assetClass.sumBorrowingRate, 0);
      assertEq(_assetClass.lastBorrowingTime, 100);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

      // no more borrowing fee to protocol fee, that portion should be at hlp liquidity
      assertEq(vaultStorage.protocolFees(address(usdt)), 0);

      // untouched
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1000000 * 1e6);
      assertEq(vaultStorage.devFees(address(usdt)), 0);
    }

    vm.warp(101);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      // 0.0001 * 90000 / 1000000 = 0.000009
      assertEq(_assetClass.sumBorrowingRate, 0.000009 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 101);

      // Fee: 0.000009 * 90000 = 0.81
      // 1 * 100 = 100 | 100 - 0.81 = 99.19
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 99.19 * 1e6);

      // no more borrowing fee to protocol fee, that portion should be at hlp liquidity
      assertEq(vaultStorage.protocolFees(address(usdt)), 0);
      // 0.81 * 85% = 0.6885
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1000000.6885 * 1e6);
      // 0.81 * 15% = 0.1215
      assertEq(vaultStorage.devFees(address(usdt)), 0.1215 * 1e6);
    }

    vm.warp(120);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      // 0.0001 * 180000 / 1000000.6885 * (120 - 101) = 0.000341999764533162 | 0.000009 + 0.000341999764533162 = 0.000350999764533162
      assertEq(_assetClass.sumBorrowingRate, 0.000350999764533162 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 120);

      // Fee: (0.000350999764533162 - 0.000009) * 180000 = 61.55995761596916
      // 99.19 - 61.55995761596916 = 37.63004238403084
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 37.630043 * 1e6);

      // 61.55995761596916 * 85% = 52.325964 | 1000000.6885 + 52.325964 = 1000053.014464
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1000053.014464 * 1e6);
      // 61.55995761596916 * 15% = 9.233993 | 0.1215 + 9.233993 = 9.355493
      assertEq(vaultStorage.devFees(address(usdt)), 9.355493 * 1e6);
    }
  }

  function testCorrectness_borrowingFee_WhenDecreasePosition() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 1_000_000 * 1e6);

    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    address bobAddress = getSubAccount(BOB, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100 * 1e6);
    vaultStorage.increaseTraderBalance(bobAddress, address(usdt), 50 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);

      assertEq(_assetClass.sumBorrowingRate, 0);
      assertEq(_assetClass.lastBorrowingTime, 100);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      // no more borrowing fee to protocol fee, that portion should be at hlp liquidity
      assertEq(vaultStorage.protocolFees(address(usdt)), 0);

      // untouched
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1000000 * 1e6);
      assertEq(vaultStorage.devFees(address(usdt)), 0);
    }

    vm.warp(110);
    {
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, address(0), 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      // 0.0001 * 135000 / 1000000 * (110 - 100) = 0.000135
      assertEq(_assetClass.sumBorrowingRate, 0.000135 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 110);

      // Fee: 90000 * 0.000135 = 12.15
      // Alice Balance: 100 - 12.15 = 87.85
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 87.85 * 1e6);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      // 12.15 * 0.85 = 10.3275 | 1000000 + 10.3275 = 1000010.3275
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1000010.3275 * 1e6);
      // 12.15 * 0.15 = 1.8225
      assertEq(vaultStorage.devFees(address(usdt)), 1.8225 * 1e6);
    }
  }

  function testCorrectness_borrowingFee_calculation() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 1_000_000 * 1e6);

    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);
    // BTC price 24000 USD
    mockOracle.setPrice(wbtcAssetId, 24000 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(weth), 1.01 * 1e18);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100 * 1e6);

    address bobAddress = getSubAccount(BOB, 0);
    vaultStorage.increaseTraderBalance(bobAddress, address(wbtc), 0.01 * 1e8);
    vaultStorage.increaseTraderBalance(bobAddress, address(usdt), 50 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);

      assertEq(_assetClass.sumBorrowingRate, 0);
      assertEq(_assetClass.lastBorrowingTime, 100);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1.01 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

      assertEq(vaultStorage.traderBalances(bobAddress, address(wbtc)), 0.01 * 1e8);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      assertEq(vaultStorage.protocolFees(address(usdt)), 0);

      assertEq(vaultStorage.devFees(address(usdt)), 0);
    }

    vm.warp(110);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, btcMarketIndex, 500_000 * 1e30, 0);

      {
        IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
        // 0.0001 * 135000 / 1000000 * (110 - 100) = 0.000135
        assertEq(_assetClass.sumBorrowingRate, 0.000135 * 1e18);
        assertEq(_assetClass.lastBorrowingTime, 110);
      }

      // 12.15 / 1600 = 0.00759375 | 1.01 - 0.00759375 = 1.00240625
      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1.00240625 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

      assertEq(vaultStorage.traderBalances(bobAddress, address(wbtc)), 0.01 * 1e8);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      // prove borrowing fee must not distributed to protocol fee
      assertEq(vaultStorage.protocolFees(address(weth)), 0);
      // 0.00759375 * 85% = 0.0064546875
      assertEq(vaultStorage.hlpLiquidity(address(weth)), 0.0064546875 * 1e18);
      // 0.00759375 * 15% = 0.0011390625
      assertEq(vaultStorage.devFees(address(weth)), 0.0011390625 * 1e18);
    }

    vm.warp(150);
    {
      // weth reserve has decreased for 180,000 USD
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 2_000_000 * 1e30, address(0), 0);
      tradeService.decreasePosition(BOB, 0, btcMarketIndex, 100_000 * 1e30, address(0), 0);

      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      // 0.0001 * 270000 / 1000010.3275 * (150 - 110) = 0.001079988846415188 | 0.000135 + 0.001079988846415188 = 0.001215
      assertEq(_assetClass.sumBorrowingRate, 0.001214988846415188 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 150);

      // 0.001079988846415188 * 180000 = 194.39799235473384
      // 194.39799235473384 / 1600 = 0.12149874522170865 | 1.00240625 - 0.12149874522170865 = 0.88090750477829135
      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 0.88090750477829135 * 1e18);
      // usdt should not affected when can gather fee from weth
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

      // 0.001079988846415188 * 45000 = 48.59949808868346
      // 48.59949808868346 / 24000 = 0.00202497 | 0.01 - 0.00202497 = 0.00797503
      assertEq(vaultStorage.traderBalances(bobAddress, address(wbtc)), 0.00797503 * 1e8);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      // 0.12149874522170865 * 15% = 0.018224811783256297 | 0.0011390625 + 0.018224811783256297 = 0.019363874283256297
      assertEq(vaultStorage.devFees(address(weth)), 0.019363874283256297 * 1e18);
      // 0.12149874522170865 - 0.018224811783256297 = 0.103273933438452353
      assertEq(vaultStorage.hlpLiquidity(address(weth)), 0.109728620938452353 * 1e18);

      // 0.00202497 * 15% = 0.00030374
      assertEq(vaultStorage.devFees(address(wbtc)), 0.00030374 * 1e8);
      // 0.00202497 - 0.00030374 = 0.00172123
      assertEq(vaultStorage.hlpLiquidity(address(wbtc)), 0.00172123 * 1e8);

      // prove not get any alice usdt because weth enough
      // and not affect to hlp liquidity
      assertEq(vaultStorage.devFees(address(usdt)), 0);
      assertEq(vaultStorage.hlpLiquidity(address(usdt)), 1_000_000 * 1e6);
    }
  }

  function testCorrectness_pendingBorrowingFee() external {
    // TVL - make the hlp value
    // 1000000 USDT -> 1000000 USD
    vaultStorage.addHLPLiquidity(address(usdt), 500_000 * 1e6);
    vaultStorage.addHLPLiquidity(address(usdc), 500_000 * 1e6);

    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);
    MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getPendingBorrowingFeeE30");

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    address bobAddress = getSubAccount(BOB, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100 * 1e6);
    vaultStorage.increaseTraderBalance(bobAddress, address(usdt), 50 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      assertEq(_assetClass.reserveValueE30, 90000 * 1e30);
      assertEq(_assetClass.sumBorrowingRate, 0);
      assertEq(_assetClass.lastBorrowingTime, 100);
      assertEq(_assetClass.sumBorrowingFeeE30, 0);
      assertEq(_assetClass.sumSettledBorrowingFeeE30, 0);

      assertEq(mockCalculator.getPendingBorrowingFeeE30(), 0, "PendingBorrowingFee T100");
    }

    vm.warp(101);
    {
      // Try again with Alice, there should be no pending borrowing fee, as there is only Alice in the game.
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);
      // 0.0001 * 90000 / 1000000 = 0.000009
      assertEq(_assetClass.reserveValueE30, 135000 * 1e30);
      assertEq(_assetClass.sumBorrowingRate, 0.000009 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 101);

      // 0.000009 * 90000 = 0.81
      assertEq(_assetClass.sumBorrowingFeeE30, 0.81 * 1e30);
      assertEq(_assetClass.sumSettledBorrowingFeeE30, 0.81 * 1e30);

      // no pending
      assertEq(mockCalculator.getPendingBorrowingFeeE30(), 0, "PendingBorrowingFee T101");
    }

    vm.warp(102);
    {
      // Last fee to Hlp = 0.81 * 85% = 0.6885
      // Hlp Value = 1000000 + 0.6885 = 1000000.6885
      // BorrowingRate: 0.0001 * 135000 / 1000000.6885 * (102 - 101) = 0.000013499990705256
      // BorrowingFee: 0.000013499990705256 * 135000 = 1.82249874520956
      assertEq(mockCalculator.getPendingBorrowingFeeE30(), 1.82249874520956 * 1e30, "PendingBorrowingFee T102");
    }

    vm.warp(110);
    {
      // Bob buys on USDT
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(0);

      // 0.0001 * 135000 / 1000000.6885 * (110 - 101) = 0.000121499916347307 | 0.000009 + 0.000121499916347307 = 0.000130499916347307
      assertEq(_assetClass.reserveValueE30, 225000 * 1e30);
      assertEq(_assetClass.sumBorrowingRate, 0.000130499916347307 * 1e18);
      assertEq(_assetClass.lastBorrowingTime, 110);

      // SumFee = 0.81 + (nextBorrowingRate * reserveValue)
      // 0.81 + (0.000121499916347307 * 135000) ~= 17.212488706886445
      assertEq(_assetClass.sumBorrowingFeeE30, 17.212488706886445 * 1e30);
      // SumSettledFee = Alice(T:100 to 101)
      //               = 0.81
      // So, it remains the same
      assertEq(_assetClass.sumSettledBorrowingFeeE30, 0.81 * 1e30);

      // At this point, can still ignore BOB, as BOB has just joined, timeDelta = 0
      // Last fee to Hlp = 0.81 * 85% = 0.6885
      // Hlp Value = 1000000 + 0.6885 = 1000000.6885
      // BorrowingRate: 0.0001 * 135000 / 1000000.6885 * (110 - 101) = 0.000121499916347307
      // BorrowingFee: 0.000121499916347307 * 135000 = 16.402488706886444
      assertEq(mockCalculator.getPendingBorrowingFeeE30(), 16.402488706886445 * 1e30, "PendingBorrowingFee T110");
    }

    vm.warp(120);
    {
      // Last fee to Hlp = 0.81 * 85% = 0.6885
      // Hlp Value = 1000000 + 0.6885 = 1000000.6885

      // T110-120 portion
      // BorrowingRate: 0.0001 * 225000 / 1000000.6885 * (120 - 110) = 0.000224999845087606
      // BorrowingFee: 0.000224999845087606 * 225000 = 50.62496514471135

      // Final anwser = (T110-120 portion) + (T101-110 portion)
      // = 50.62496514471135 + 16.402488706886445 = 67.027453851597795
      assertEq(mockCalculator.getPendingBorrowingFeeE30(), 67.027453851597795 * 1e30, "PendingBorrowingFee T120");
    }
  }
}
