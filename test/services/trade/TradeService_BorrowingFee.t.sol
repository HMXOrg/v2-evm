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
        address(mockOracle),
        address(vaultStorage),
        address(perpStorage),
        address(configStorage)
      );
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getBorrowingFee");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getNextBorrowingRate");
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("getPLPValueE30");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
      tradeHelper.reloadConfig();
    }
  }

  // function testCorrectness_borrowingFee_WhenIncreasePosition() external {
  //   // TVL - make the plp value
  //   // 1000000 USDT -> 1000000 USD
  //   vaultStorage.addPLPLiquidity(address(usdt), 1_000_000 * 1e6);

  //   // ALICE add collateral
  //   // 10000 USDT -> free collateral -> 10000 USD
  //   mockCalculator.setFreeCollateral(10_000 * 1e30);

  //   // ETH price 1600 USD
  //   mockOracle.setPrice(wethAssetId, 1600 * 1e30);
  //   // USDT price 1 USD
  //   mockOracle.setPrice(usdtAssetId, 1 * 1e30);

  //   address aliceAddress = getSubAccount(ALICE, 0);
  //   address bobAddress = getSubAccount(BOB, 0);
  //   vaultStorage.setTraderBalance(aliceAddress, address(usdt), 10 * 1e6);

  //   vm.warp(100);
  //   {
  //     tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 100);

  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 10 * 1e6);

  //     assertEq(vaultStorage.protocolFees(address(usdt)), 0);

  //     assertEq(vaultStorage.devFees(address(usdt)), 0);
  //   }

  //   vm.warp(101);
  //   {
  //     tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 90000 / 1000000 = 0.000009
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.000009 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 101);

  //     // 0.000009 * 90000 = 0.81
  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 0);

  //     // 1 * 10 = 10 | 10 - 0.81 = 9.19
  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 9.19 * 1e6);

  //     // 0.81 * 85% = 0.6885
  //     assertEq(vaultStorage.protocolFees(address(usdt)), 0.6885 * 1e6);
  //     // 0.81 * 15% = 0.1215
  //     assertEq(vaultStorage.devFees(address(usdt)), 0.1215 * 1e6);
  //   }

  //   vm.warp(120);
  //   {
  //     tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 180000 / 1000000 * (120 - 101) = 0.000342 | 0.000009 + 0.000342 = 0.000351
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.000351 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 120);

  //     // (0.000351 - 0.000009) * 180000 = 61.56 | 61.56 - 9.19 = 52.37
  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 52.37 * 1e30);

  //     // 1 * 9.19 = 9.19 | 9.19 - 9.19 = 0
  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 0);

  //     // 9.19 * 85% = 7.8115 | 0.6885 + 7.8115 = 8.5
  //     assertEq(vaultStorage.protocolFees(address(usdt)), 8.5 * 1e6);
  //     // 9.19 * 15% = 1.3785 | 0.1215 + 1.3785 = 1.5
  //     assertEq(vaultStorage.devFees(address(usdt)), 1.5 * 1e6);
  //   }

  //   vm.warp(130);
  //   {
  //     tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 270000 / 1000000 * (130 - 120) = 0.00027 | 0.000351 + 0.00027 = 0.000621
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.000621 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 130);

  //     // (0.000621 - 0.000351) * 270000 = 30.78 | 52.37 + 30.78 = 83.15
  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 52.37 * 1e30);
  //     assertEq(perpStorage.getSubAccountFee(bobAddress), 0);

  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 0);
  //     assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 0);

  //     assertEq(vaultStorage.protocolFees(address(usdt)), 8.5 * 1e6);
  //     assertEq(vaultStorage.devFees(address(usdt)), 1.5 * 1e6);
  //   }

  //   vm.warp(135);
  //   {
  //     tradeService.increasePosition(BOB, 0, ethMarketIndex, 200_000 * 1e30, 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 315000 / 1000000 * (135 - 130) = 0.0001575 | 0.000621 + 0.0001575 = 0.0007785
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.0007785 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 135);

  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 52.37 * 1e30);
  //     // (0.0007785 - 0.000621) * 45000 = 7.0875
  //     assertEq(perpStorage.getSubAccountFee(bobAddress), 7.0875 * 1e30);

  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 0);
  //     assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 0);

  //     assertEq(vaultStorage.protocolFees(address(usdt)), 8.5 * 1e6);
  //     assertEq(vaultStorage.devFees(address(usdt)), 1.5 * 1e6);
  //   }
  // }

  // function testCorrectness_borrowingFee_WhenDecreasePosition() external {
  //   // TVL
  //   // 1000000 USDT -> 1000000 USD
  //   vaultStorage.addPLPLiquidity(address(usdt), 1_000_000 * 1e6);

  //   // ALICE add collateral
  //   // 10000 USDT -> free collateral -> 10000 USD
  //   mockCalculator.setFreeCollateral(10_000 * 1e30);

  //   // ETH price 1600 USD
  //   mockOracle.setPrice(wethAssetId, 1600 * 1e30);
  //   // USDT price 1 USD
  //   mockOracle.setPrice(usdtAssetId, 1 * 1e30);

  //   address aliceAddress = getSubAccount(ALICE, 0);
  //   address bobAddress = getSubAccount(BOB, 0);
  //   vaultStorage.setTraderBalance(aliceAddress, address(usdt), 10 * 1e6);
  //   vaultStorage.setTraderBalance(bobAddress, address(usdt), 5 * 1e6);

  //   vm.warp(100);
  //   {
  //     tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
  //     tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);

  //     assertEq(_globalAssetClass.sumBorrowingRate, 0);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 100);

  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 10 * 1e6);
  //     assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 5 * 1e6);

  //     assertEq(vaultStorage.protocolFees(address(usdt)), 0);

  //     assertEq(vaultStorage.devFees(address(usdt)), 0);
  //   }

  //   vm.warp(110);
  //   {
  //     tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, address(0), 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 135000 / 1000000 * (110 - 100) = 0.000135
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.000135 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 110);

  //     // (0.000135 - 0) * 90000 = 18.225 | 12.15 - 10 = 2.15
  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 2.15 * 1e30);
  //     assertEq(perpStorage.getSubAccountFee(bobAddress), 0);

  //     // 12.15 - 10 = 0
  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 0);
  //     assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 5 * 1e6);

  //     // 10 * 85% = 8.5
  //     assertEq(vaultStorage.protocolFees(address(usdt)), 8.5 * 1e6);
  //     // 10 * 15% = 1.5
  //     assertEq(vaultStorage.devFees(address(usdt)), 1.5 * 1e6);
  //   }

  //   vm.warp(120);
  //   {
  //     tradeService.decreasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, address(0), 0);
  //     IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
  //     // 0.0001 * 90000 / 1000000 * (120 - 110) = 0.00009 | 0.000135 + 0.00009 = 0.000225
  //     assertEq(_globalAssetClass.sumBorrowingRate, 0.000225 * 1e18);
  //     assertEq(_globalAssetClass.lastBorrowingTime, 120);

  //     assertEq(perpStorage.getSubAccountFee(aliceAddress), 2.15 * 1e30);
  //     // (0.000225 - 0) * 45000 = 10.125 | 10.125 - 5 = 5.125
  //     assertEq(perpStorage.getSubAccountFee(bobAddress), 5.125 * 1e30);

  //     assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 0);
  //     // 10.125 - 5 = 0
  //     assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 0);

  //     // 5 * 85% = 4.25 | 8.5 + 4.25 = 12.75
  //     assertEq(vaultStorage.protocolFees(address(usdt)), 12.75 * 1e6);
  //     // 5 * 15% = 0.75 | 1.5 + 0.75 = 2.25
  //     assertEq(vaultStorage.devFees(address(usdt)), 2.25 * 1e6);
  //   }
  // }

  function testCorrectness_borrowingFee_calculation() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    vaultStorage.addPLPLiquidity(address(usdt), 1_000_000 * 1e6);

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
    vaultStorage.setTraderBalance(aliceAddress, address(weth), 1.01 * 1e18);
    vaultStorage.setTraderBalance(aliceAddress, address(usdt), 100 * 1e6);

    address bobAddress = getSubAccount(BOB, 0);
    vaultStorage.setTraderBalance(bobAddress, address(wbtc), 0.01 * 1e8);
    vaultStorage.setTraderBalance(bobAddress, address(usdt), 50 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
      tradeService.increasePosition(BOB, 0, ethMarketIndex, 500_000 * 1e30, 0);

      IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);

      assertEq(_globalAssetClass.sumBorrowingRate, 0);
      assertEq(_globalAssetClass.lastBorrowingTime, 100);

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
        IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
        // 0.0001 * 135000 / 1000000 * (110 - 100) = 0.000135
        assertEq(_globalAssetClass.sumBorrowingRate, 0.000135 * 1e18);
        assertEq(_globalAssetClass.lastBorrowingTime, 110);
      }

      // (0.000135 - 0) * 90000 = 12.15 | 0.01 * 1600 = 16 | 12.15 - 16 = 0 |
      assertEq(perpStorage.getSubAccountFee(aliceAddress), 0);
      assertEq(perpStorage.getSubAccountFee(bobAddress), 0);

      // 12.15 / 1600 = 0.00759375 | 1.01 - 0.00759375 = 1.00240625
      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1.00240625 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

      assertEq(vaultStorage.traderBalances(bobAddress, address(wbtc)), 0.01 * 1e8);
      assertEq(vaultStorage.traderBalances(bobAddress, address(usdt)), 50 * 1e6);

      // prove borrowing fee must not distributed to protocol fee
      assertEq(vaultStorage.protocolFees(address(weth)), 0);
      // 0.00759375 * 85% = 0.0064546875
      assertEq(vaultStorage.plpLiquidity(address(weth)), 0.0064546875 * 1e18);
      // 0.00759375 * 15% = 0.0011390625
      assertEq(vaultStorage.devFees(address(weth)), 0.0011390625 * 1e18);
    }

    vm.warp(150);
    {
      // weth reserve has decreased for 180,000 USD
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 2_000_000 * 1e30, address(0), 0);
      tradeService.decreasePosition(BOB, 0, btcMarketIndex, 100_000 * 1e30, address(0), 0);

      IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
      // 0.0001 * 270000 / 1000010.3275 * (150 - 110) = 0.001079988846415188 | 0.000135 + 0.001079988846415188 = 0.001215
      assertEq(_globalAssetClass.sumBorrowingRate, 0.001214988846415188 * 1e18);
      assertEq(_globalAssetClass.lastBorrowingTime, 150);

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
      assertEq(vaultStorage.plpLiquidity(address(weth)), 0.109728620938452353 * 1e18);

      // 0.00202497 * 15% = 0.00030374
      assertEq(vaultStorage.devFees(address(wbtc)), 0.00030374 * 1e8);
      // 0.00202497 - 0.00030374 = 0.00172123
      assertEq(vaultStorage.plpLiquidity(address(wbtc)), 0.00172123 * 1e8);

      // prove not get any alice usdt because weth enough
      // and not affect to plp liquidity
      assertEq(vaultStorage.devFees(address(usdt)), 0);
      assertEq(vaultStorage.plpLiquidity(address(usdt)), 1_000_000 * 1e6);
    }
  }
}
