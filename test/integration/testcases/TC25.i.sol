// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { console } from "forge-std/console.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract TC25 is BaseIntTest_WithActions {
  function test_correctness_PLP_effectPriceChange() external {
    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB is open position

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(ALICE, ERC20(address(wbtc)), 100 * 1e8, executionOrderFee, initialPriceFeedDatas, true);

    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 100_000 * 1e6);

    addLiquidity(ALICE, ERC20(address(usdc)), 100_000 * 1e6, executionOrderFee, initialPriceFeedDatas, true);
    {
      // PLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertPLPTotalSupply(2_094_000 * 1e18);
      // assert PLP
      assertTokenBalanceOf(ALICE, address(plpV2), 2_094_000 * 1e18);
      assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertPLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    //  Deposit Collateral => 1000 dollar
    // fee increase position

    usdc.mint(BOB, 300_230 * 1e6);

    depositCollateral(BOB, 0, ERC20(address(usdc)), 300_230 * 1e6);

    {
      // Assert collateral (PLP 100,000 + Collateral 1,000) => 101_000
      assertVaultTokenBalance(address(usdc), 400_230 * 1e6, "TC25: ");
    }

    //  Open position
    // - Long  BTCUSD 100,000 USD (Tp in wbtc) //  (100_000 + 0.1%) => 100_100
    // - Long JPYUSD 100,000 USD (tp in usdc) // (100_000 + 0.03%)  => 100_030
    // - Short ETHUSD 100,000 USD (tp in usdc) //  (100_000 + 0.1%) => 100_100
    uint256 _pythGasFee = initialPriceFeedDatas.length;
    vm.deal(BOB, _pythGasFee * 3);

    // Long BTC
    // Short ETH
    // LONG JPY
    marketBuy(BOB, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), initialPriceFeedDatas);
    marketBuy(BOB, 0, jpyMarketIndex, 100_000 * 1e30, address(usdc), initialPriceFeedDatas);
    marketSell(BOB, 0, wethMarketIndex, 100_000 * 1e30, address(usdc), initialPriceFeedDatas);
    // console.log("==================== BEFORE ====================");

    // PLP LIQUIDITY 99.7 WBTC, 100_000 usdc

    {
      /* 
      BEFORE

      PLP VALUE = 2094000000000000000000000000000000000
      assetIds	value
      usdc	  100000000000000000000000000000000000
      usdt	  0
      dai	    0
      weth	  0
      wbtc	  1994000000000000000000000000000000000 (20_000 * 99.7)

      PNL = -49997223611033789217594141892156
      Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
      WBTC   LONG         20000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              -16663889351774637571514007233310
      JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774637571514003575322
      WETH   SHORT        1500000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              -16669444907484514074566131083524

      Pending Borrowing Fee = 0 (no skip)
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM = 2094000000000000000000000000000000000- (-49997223611033789217594141892156) +0
      AUM =  2094049997223611033789217594141892156
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit
      */

      uint256 plpValueBefore = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeBefore = calculator.getPendingBorrowingFeeE30();
      uint256 aumBefore = calculator.getAUME30(false);
      assertEq(plpValueBefore, 2094000000000000000000000000000000000, "PLP TVL Before Feed Price");
      assertEq(pendingBorrowingFeeBefore, 0, "Pending Borrowing Fee Before Feed Price");
      assertEq(aumBefore, 2094049997223611033789217594141892156, "AUM Before Feed Price");
      assertEq(
        -int256(aumBefore - plpValueBefore - pendingBorrowingFeeBefore),
        -49997223611033789217594141892156,
        "GLOBAL PNLE30"
      );
    }

    // T2: Price changed (at same block, no borrowing fee in this case)
    // - BTC 20,000 => 23,000
    // - ETH 1,500 => 1,800
    {
      bytes32[] memory _newAssetIds = new bytes32[](2);
      int64[] memory _prices = new int64[](2);
      uint64[] memory _conf = new uint64[](2);
      _newAssetIds[0] = wbtcAssetId;
      _prices[0] = 21_000 * 1e8;
      _conf[0] = 0;

      _newAssetIds[1] = wethAssetId;
      _prices[1] = 1_800 * 1e8;
      _conf[1] = 0;

      bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
    }

    //  ASSERT AFTER

    {
      /*
      AFTER

      assetIds	value
      usdc	  100000000000000000000000000000000000
      usdt	  0
      dai	    0
      weth	  0
      wbtc	  2093700000000000000000000000000000000 (21_000 * 99.7)

      PNL = -15054164307060119423911083068470528
      Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
      WBTC   LONG         21000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              4982502916180636630549910292405023
      JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774637571514003575322
      WETH   SHORT        1800000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              -20020003333888981416889479357300229

      Pending Borrowing Fee = 0 (no skip)
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM =  2193700000000000000000000000000000000 - (-15054164307060119423911083068470528) + 0 
      AUM = 2208754164307060119423911083068470528
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

      */

      uint256 plpValueAfter = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
      uint256 aumAfter = calculator.getAUME30(false);
      assertEq(aumAfter, 2208754164307060119423911083068470528, "AUM After Feed Price T4");
      assertEq(plpValueAfter, 2193700000000000000000000000000000000, "PLP TVL After Feed Price T4");
      assertEq(pendingBorrowingFeeAfter, 0, "Pending Borrowing Fee After Feed Price T4");
      assertEq(
        -int256(aumAfter - plpValueAfter - pendingBorrowingFeeAfter),
        -15054164307060119423911083068470528,
        "GLOBAL PNLE30 After Feed Price T4"
      );
    }

    // T3: FEED PRICE
    // - ETH 1,800->1,000
    {
      skip(1);
      bytes32[] memory _newAssetIds = new bytes32[](1);
      int64[] memory _prices = new int64[](1);
      uint64[] memory _conf = new uint64[](1);

      _newAssetIds[0] = wethAssetId;
      _prices[0] = 1_000 * 1e8;
      _conf[0] = 0;

      bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
    }

    {
      /*
      AFTER

      assetIds	value
      usdc	  100000000000000000000000000000000000
      usdt	  0
      dai	    0
      weth	  0
      wbtc	  2093700000000000000000000000000000000 (21_000 * 99.7)

      PNL = 38288059396890538983595352201440684
      Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
      WBTC   LONG         21000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              4982502916180636630549910292405023
      JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774637571514003575322
      WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              33322220370061676990616955912610983

      Pending Borrowing Fee = 0 (no skip)
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM =  2193700000000000000000000000000000000 - (38288059396890538983595352201440684) + 0 
      AUM =  2155411940603109461016404647798559316
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

      */

      uint256 plpValueAfter = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
      uint256 aumAfter = calculator.getAUME30(false);
      assertEq(aumAfter, 2155411940603109461016404647798559316, "AUM After Feed Price T4");
      assertEq(plpValueAfter, 2193700000000000000000000000000000000, "PLP TVL After Feed Price T4");
      assertEq(pendingBorrowingFeeAfter, 0, "Pending Borrowing Fee After Feed Price T4");
      assertEq(
        -int256(aumAfter - plpValueAfter - pendingBorrowingFeeAfter),
        -15054164307060119423911083068470528,
        "GLOBAL PNLE30 After Feed Price T4"
      );
    }

    // T10: Add BTC in plp
    // T6: BTC price changed to 18,000 (check AUM)
  }
}
