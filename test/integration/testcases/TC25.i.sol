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
      PLP VALUE = 2193700000000000000000000000000000000
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
      int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
      assertEq(pnlAfter, -15054164307060119423911083068470528, "GLOBAL PNLE30 After Feed Price T4");
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

      PLP VALUE = 2193700000000000000000000000000000000
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

      Pending Borrowing Fee =  14880339153010800000000000000
                                
         NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
          BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
      Pending Forex (JPY position) => 
          NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 1 ) / 2193700000000000000000000000000000000 = 123079728312
          Borrowing Fee = 123079728312 * 900000000000000000000000000000000 / 1e18 => 110771755480800000000000000
                                                                                     
                                                                                     
      Pending Crypto (WETH, WBTC position) =>
          NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 1 ) / 2193700000000000000000000000000000000 = 820531522085
          Borrowing Fee =  820531522085 * 18000000000000000000000000000000000 / 1e18 =>  14769567397530000000000000000
      Pending Equity => 0 (no position)

   
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM =  2193700000000000000000000000000000000 - (38288059396890538983595352201440684) + 14880339153010800000000000000
      AUM =  2155411955483448614027204647798559316
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

      */

      uint256 plpValueAfter = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
      uint256 aumAfter = calculator.getAUME30(false);
      int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
      assertEq(aumAfter, 2155411955483448614027204647798559316, "AUM After Feed Price T5");
      assertEq(plpValueAfter, 2193700000000000000000000000000000000, "PLP TVL After Feed Price T5");
      assertEq(pendingBorrowingFeeAfter, 14880339153010800000000000000, "Pending Borrowing Fee After Feed Price T5");
      assertEq(pnlAfter, 38288059396890538983595352201440684, "GLOBAL PNLE30 After Feed Price T5");
    }

    // T4: Add BTC in plp
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 5 * 1e8);

    addLiquidity(ALICE, ERC20(address(wbtc)), 5 * 1e8, executionOrderFee, new bytes[](0), true);

    //check total Supply 101692116183347924027667
    {
      // Fee = 0.31%, Old Supply 2_094_000.00, PNL = 38288059396890538983595352201440684, Borrowing fee => 14880339153010800000000000000
      // PLP => 1_994_000.00(WBTC)+ 100_000 (USDC)  + 101692.116183347924027667 (WBTC)
      // PLP => 2195692116183347924027667
      assertPLPTotalSupply(2195692116183347924027667);

      // assert PLP
      // BTC in liquidity
      // assertTokenBalanceOf(ALICE, address(plpV2), 2_193_917.22 * 1e18);
      // 99.7 + 4.984500
      assertPLPLiquidity(address(wbtc), 104.6845 * 1e8);
      assertPLPLiquidity(address(usdc), 100_000 * 1e6);

      /*
      AFTER

      PLP VALUE = 2298374500000000000000000000000000000
      assetIds	value
      usdc	  100000000000000000000000000000000000
      usdt	  0
      dai	    0
      weth	  0
      wbtc	  2198374500000000000000000000000000000 (21_000 * 104.6845)

      PNL = 38288059396890538983595352201440684
      Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
      WBTC   LONG         21000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              4982502916180636630549910292405023
      JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774637571514003575322
      WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              33322220370061676990616955912610983

      Pending Borrowing Fee =  14202646261516800000000000000 (plpTVL is changed)
                                
         NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
          BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
      Pending Forex (JPY position) => 
          NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 1 ) / 2298374500000000000000000000000000000 = 117474328052
          Borrowing Fee = 117474328052 * 900000000000000000000000000000000 / 1e18 => 105726895246800000000000000
                                                                                     
                                                                                     
      Pending Crypto (WETH, WBTC position) =>
          NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 1 ) / 2298374500000000000000000000000000000 = 783162187015
          Borrowing Fee =  783162187015 * 18000000000000000000000000000000000 / 1e18 =>  14096919366270000000000000000
      Pending Equity => 0 (no position)

   
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM =  2298374500000000000000000000000000000 - (38288059396890538983595352201440684) + 14202646261516800000000000000
      AUM =  2260086454805755722533204647798559316
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

      */

      uint256 plpValueAfter = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
      uint256 aumAfter = calculator.getAUME30(false);
      int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
      assertEq(aumAfter, 2260086454805755722533204647798559316, "AUM ");
      assertEq(plpValueAfter, 2298374500000000000000000000000000000, "PLP TVL");
      assertEq(pendingBorrowingFeeAfter, 14202646261516800000000000000, "Pending Borrowing Fee");
      assertEq(pnlAfter, 38288059396890538983595352201440684, "GLOBAL PNLE30 ");
    }
    // T6: BTC price changed to 18,000 (check AUM)
    {
      skip(1);
      bytes32[] memory _newAssetIds = new bytes32[](1);
      int64[] memory _prices = new int64[](1);
      uint64[] memory _conf = new uint64[](1);

      _newAssetIds[0] = wbtcAssetId;
      _prices[0] = 18_000 * 1e8;
      _conf[0] = 0;

      bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
    }

    {
      /*
      AFTER

      PLP VALUE = 1984321000000000000000000000000000000
      assetIds	value
      usdc	  100000000000000000000000000000000000
      usdt	  0
      dai	    0
      weth	  0
      wbtc	  1884321000000000000000000000000000000 (18_000 * 104.6845)

      PNL = 23290558980293305179231079302525682
      Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
      WBTC   LONG         18000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              -10014997500416597173814362606509979
      JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774637571514003575322
      WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              33322220370061676990616955912610983

      Pending Borrowing Fee = 32900926815763200000000000000
                                
         NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
          BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
      Pending Forex (JPY position) => 
          NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 2 ) / 1984321000000000000000000000000000000 = 272133389708
          Borrowing Fee = 272133389708 * 900000000000000000000000000000000 / 1e18 => 244920050737200000000000000
                                                                                     
                                                                                     
      Pending Crypto (WETH, WBTC position) =>
          NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 2 ) / 1984321000000000000000000000000000000 = 1814222598057
          Borrowing Fee =  1814222598057 * 18000000000000000000000000000000000 / 1e18 =>  32656006765026000000000000000
      Pending Equity => 0 (no position)

   
      AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
      AUM =  1984321000000000000000000000000000000 - (23290558980293305179231079302525682) + 32900926815763200000000000000
      AUM =  1961030473920633510583968920697474318
      PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

      */
      uint256 plpValueAfter = calculator.getPLPValueE30(false);
      uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
      uint256 aumAfter = calculator.getAUME30(false);
      int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
      assertEq(aumAfter, 1961030473920633510583968920697474318, "AUM ");
      assertEq(plpValueAfter, 1984321000000000000000000000000000000, "PLP TVL");
      assertEq(pendingBorrowingFeeAfter, 32900926815763200000000000000, "Pending Borrowing Fee");
      assertEq(pnlAfter, 23290558980293305179231079302525682, "GLOBAL PNLE30 ");
    }
  }
}
