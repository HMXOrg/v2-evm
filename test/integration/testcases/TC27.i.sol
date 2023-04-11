// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
// import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
// import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

// contract TC27 is BaseIntTest_WithActions {
//   function test_correctness_PLP_disableDynamicFee() external {
//     // T0: Initialized state
//     configStorage.setDynamicEnabled(false);
//     // ALICE as liquidity provider
//     // BOB is open position

//     // T1: Add liquidity in pool USDC 100_000 , WBTC 100
//     vm.deal(ALICE, executionOrderFee);
//     wbtc.mint(ALICE, 100 * 1e8);

//     addLiquidity(ALICE, ERC20(address(wbtc)), 100 * 1e8, executionOrderFee, initialPriceFeedDatas, true);

//     vm.deal(ALICE, executionOrderFee);
//     usdc.mint(ALICE, 100_000 * 1e6);

//     addLiquidity(ALICE, ERC20(address(usdc)), 100_000 * 1e6, executionOrderFee, initialPriceFeedDatas, true);
//     {
//       // PLP => 1_994_000.00(WBTC) + 99_700 (USDC)
//       assertPLPTotalSupply(2_093_700 * 1e18);
//       // assert PLP
//       assertTokenBalanceOf(ALICE, address(plpV2), 2_093_700 * 1e18);

//       assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
//       assertPLPLiquidity(address(usdc), 99_700 * 1e6);
//     }

//     // fee increase position

//     usdc.mint(BOB, 300_230 * 1e6);

//     depositCollateral(BOB, 0, ERC20(address(usdc)), 300_230 * 1e6);

//     {
//       // Assert collateral (PLP 100,000 + Collateral 1,000) => 101_000
//       assertVaultTokenBalance(address(usdc), 400_230 * 1e6, "TC27: ");
//     }

//     //  Open position
//     // - Long  BTCUSD 100,000 USD (Tp in wbtc) //  (100_000 + 0.1%) => 100_100
//     // - Long JPYUSD 100,000 USD (tp in usdc) // (100_000 + 0.03%)  => 100_030
//     // - Short ETHUSD 100,000 USD (tp in usdc) //  (100_000 + 0.1%) => 100_100
//     uint256 _pythGasFee = initialPriceFeedDatas.length;
//     vm.deal(BOB, _pythGasFee * 3);

//     // Long BTC
//     // Short ETH
//     // LONG JPY
//     vm.deal(BOB, 1 ether);
//     marketBuy(BOB, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), initialPriceFeedDatas);
//     marketBuy(BOB, 0, jpyMarketIndex, 100_000 * 1e30, address(usdc), initialPriceFeedDatas);
//     marketSell(BOB, 0, wethMarketIndex, 100_000 * 1e30, address(usdc), initialPriceFeedDatas);

//     // PLP LIQUIDITY 99.7 WBTC, 99_700 usdc
//     {
//       /* 
//       BEFORE T2

//       PLP VALUE = 2093700000000000000000000000000000000
//       assetIds	value
//       usdc	  99700000000000000000000000000000000 (1 * 99700)
//       usdt	  0
//       dai	    0
//       weth	  0
//       wbtc	  1994000000000000000000000000000000000 (20000 * 99.7)

//       PNL =  -49997223611033989195388580911857
      
//       Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
//       WBTC   LONG         20000000000000000000000000000000000              20003333333333333333333333333320000              100000000000000000000000000000000000              -16663889351774704215964005932355
//       JPY    LONG         7346297098947275625720855402                     7347521481797100171658475544                     100000000000000000000000000000000000              -16663889351774704215963998283398
//       WETH   SHORT        1500000000000000000000000000000000               1499750000000000000000000000001000               100000000000000000000000000000000000              -16669444907484580763460576696104

//       Pending Borrowing Fee = 0 (no skip)
//       AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
//       AUM = 2093700000000000000000000000000000000- (-49997223611033989195388580911857) +0
//       AUM = 2093749997223611033989195388580911857
//       PNL = plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit
//       */

//       uint256 plpValueBefore = calculator.getPLPValueE30(false);
//       uint256 pendingBorrowingFeeBefore = calculator.getPendingBorrowingFeeE30();
//       uint256 aumBefore = calculator.getAUME30(false);
//       assertEq(plpValueBefore, 2093700000000000000000000000000000000, "PLP TVL Before Feed Price");
//       assertEq(pendingBorrowingFeeBefore, 0, "Pending Borrowing Fee Before Feed Price");
//       assertEq(aumBefore, 2093749997223611033989195388580911857, "AUM Before Feed Price");
//       assertEq(
//         -int256(aumBefore - plpValueBefore - pendingBorrowingFeeBefore),
//         -49997223611033989195388580911857,
//         "GLOBAL PNLE30"
//       );
//     }

//     // T2: Price changed (at same block, no borrowing fee in this case)
//     // - BTC 20,000 => 21,000
//     // - ETH 1,500 => 1,800
//     {
//       bytes32[] memory _newAssetIds = new bytes32[](2);
//       int64[] memory _prices = new int64[](2);
//       uint64[] memory _conf = new uint64[](2);
//       _newAssetIds[0] = wbtcAssetId;
//       _prices[0] = 21_000 * 1e8;
//       _conf[0] = 0;

//       _newAssetIds[1] = wethAssetId;
//       _prices[1] = 1_800 * 1e8;
//       _conf[1] = 0;

//       bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
//     }

//     //  ASSERT AFTER T2

//     {
//       /*
//       AFTER T2
//       PLP VALUE = 2193400000000000000000000000000000000
//       assetIds	value
//       usdc	  99700000000000000000000000000000000 (1 * 99700)
//       usdt	  0
//       dai	    0
//       weth	  0
//       wbtc	  2093700000000000000000000000000000000 (21000 * 99.7)

//       PNL = -15054164307060119640558878896547697
//       Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
//       WBTC   LONG         21000000000000000000000000000000000              20003333333333333333333333333320000              100000000000000000000000000000000000              4982502916180636560573237793771026
//       JPY    LONG         7346297098947275625720855402                     7347521481797100171658475544                     100000000000000000000000000000000000              -16663889351774704215963998283398
//       WETH   SHORT        1800000000000000000000000000000000               1499750000000000000000000000001000               100000000000000000000000000000000000              -20020003333888981496916152692035325

//       Pending Borrowing Fee = 0 (no skip)
//       AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
//       AUM = 2193400000000000000000000000000000000 - (-15054164307060119640558878896547697) + 0 
//       AUM = 2208454164307060119640558878896547697
//       PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit
//       */

//       uint256 plpValueAfter = calculator.getPLPValueE30(false);
//       uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
//       uint256 aumAfter = calculator.getAUME30(false);
//       assertEq(aumAfter, 2208454164307060119640558878896547697, "AUM After T2");
//       assertEq(plpValueAfter, 2193400000000000000000000000000000000, "PLP TVL After T2");
//       assertEq(pendingBorrowingFeeAfter, 0, "Pending Borrowing Fee After T2");
//       int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
//       assertEq(pnlAfter, -15054164307060119640558878896547697, "GLOBAL PNLE30 After T2");
//     }

//     // T3: FEED PRICE
//     // - ETH 1,800->1,000
//     {
//       skip(1);
//       bytes32[] memory _newAssetIds = new bytes32[](1);
//       int64[] memory _prices = new int64[](1);
//       uint64[] memory _conf = new uint64[](1);

//       _newAssetIds[0] = wethAssetId;
//       _prices[0] = 1_000 * 1e8;
//       _conf[0] = 0;

//       bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
//     }

//     // ASSERT AFTER T3
//     {
//       /*
//       AFTER T3

//       PLP VALUE = 2193400000000000000000000000000000000
//       assetIds	value
//       usdc	  99700000000000000000000000000000000 (1 * 99700)
//       usdt	  0
//       dai	    0
//       weth	  0
//       wbtc	  2093700000000000000000000000000000000 (21000 * 99.7)

//       PNL = 38288059396890538802514966744356891
//       Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
//       WBTC   LONG         21000000000000000000000000000000000              20003333333333333333333333333320000              100000000000000000000000000000000000              4982502916180636560573237793771026
//       JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774704215963998283398
//       WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              33322220370061676946157692948869263

//       Pending Borrowing Fee =  14882374395912600000000000000
                                
//          NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
//           BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
//       Pending Forex (JPY position) => 
//           NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 1 ) / 2193400000000000000000000000000000000 = 123096562414
//           Borrowing Fee = 123096562414 * 900000000000000000000000000000000 / 1e18 => 110786906172600000000000000
                                                                                     
                                                                                     
//       Pending Crypto (WETH, WBTC position) =>
//           NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 1 ) / 2193400000000000000000000000000000000 = 820643749430
//           Borrowing Fee =  820643749430 * 18000000000000000000000000000000000 / 1e18 =>  14771587489740000000000000000
//       Pending Equity => 0 (no position)

   
//       AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
//       AUM =  2193400000000000000000000000000000000 - (38288059396890538802514966744356891) + 14882374395912600000000000000
//       AUM =  2155111955485483857110085033255643109
//       PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

//       */

//       uint256 plpValueAfter = calculator.getPLPValueE30(false);
//       uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
//       uint256 aumAfter = calculator.getAUME30(false);
//       int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
//       assertEq(aumAfter, 2155111955485483857110085033255643109, "AUM After Feed Price T3");
//       assertEq(plpValueAfter, 2193400000000000000000000000000000000, "PLP TVL After Feed Price T3");
//       assertEq(pendingBorrowingFeeAfter, 14882374395912600000000000000, "Pending Borrowing Fee After Feed Price T3");
//       assertEq(pnlAfter, 38288059396890538802514966744356891, "GLOBAL PNLE30 After Feed Price T3");
//     }

//     // T4: Add BTC in plp
//     vm.deal(ALICE, executionOrderFee);
//     wbtc.mint(ALICE, 5 * 1e8);

//     addLiquidity(ALICE, ERC20(address(wbtc)), 5 * 1e8, executionOrderFee, new bytes[](0), true);

//     // ASSERT AFTER T4

//     {
//       // AFTER T4

//       // Old Supply 2_093_700.00, PNL = 38288059396890538802514966744356891, Borrowing fee => 14882374395912600000000000000 , totalLiquidityValue = 2193400000000000000000000000000000000
//       // Fee Addliquidity = 0.3%
//       // PLP => 1_994_000.00(WBTC) + 99_700.000 (USDC) + 101_701.901816337596452511 (WBTC)
//       // PLP => 2195401.901816337596452511
//       assertPLPTotalSupply(2_195_401.901816337596452511 * 1e18);

//       // assert PLP
//       // BTC in liquidity
//       assertTokenBalanceOf(ALICE, address(plpV2), 2_195_401.901816337596452511 * 1e18);
//       // 99.7 + 4.985  = 104.685
//       assertPLPLiquidity(address(wbtc), 104.685 * 1e8);
//       assertPLPLiquidity(address(usdc), 99_700 * 1e6);

//       /*

//       PLP VALUE (PLP TVL) = 2298085000000000000000000000000000000
//       assetIds	value
//       usdc	  99700000000000000000000000000000000 (1* 99700)
//       usdt	  0
//       dai	    0
//       weth	  0
//       wbtc	  2198385000000000000000000000000000000 (21_000 * 104.685)

//       PNL = 38288059396890538802514966744356891
//       Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
//       WBTC   LONG         21000000000000000000000000000000000              20003333333333333333333333333320000              100000000000000000000000000000000000              4982502916180636560573237793771026
//       JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774704215963998283398
//       WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              33322220370061676946157692948869263

//       Pending Borrowing Fee =  14204435432108400000000000000 (plpTVL is changed)
                                
//          NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
//           BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
//       Pending Forex (JPY position) => 
//           NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 1 ) / 2298085000000000000000000000000000000 = 117489126816
//           Borrowing Fee = 117489126816 * 900000000000000000000000000000000 / 1e18 => 105740214134400000000000000
                                                                                                                                                                       
//       Pending Crypto (WETH, WBTC position) =>
//           NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 1 ) / 2298085000000000000000000000000000000 = 783260845443
//           Borrowing Fee =  783260845443 * 18000000000000000000000000000000000 / 1e18 =>  14098695217974000000000000000
   
//       AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
//       AUM =  2298085000000000000000000000000000000 - (38288059396890538802514966744356891) + 14204435432108400000000000000
//       AUM =  2259796954807544893305885033255643109
//       PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

//       */

//       uint256 plpValueAfter = calculator.getPLPValueE30(false);
//       uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
//       uint256 aumAfter = calculator.getAUME30(false);
//       int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
//       assertEq(aumAfter, 2259796954807544893305885033255643109, "AUM After T4");
//       assertEq(plpValueAfter, 2298085000000000000000000000000000000, "PLP TVL After T4");
//       assertEq(pendingBorrowingFeeAfter, 14204435432108400000000000000, "Pending Borrowing Fee After T4");
//       assertEq(pnlAfter, 38288059396890538802514966744356891, "GLOBAL PNLE30  After T4");
//     }

//     // T5: BTC price changed to 18,000 (check AUM)
//     {
//       skip(1);
//       bytes32[] memory _newAssetIds = new bytes32[](1);
//       int64[] memory _prices = new int64[](1);
//       uint64[] memory _conf = new uint64[](1);

//       _newAssetIds[0] = wbtcAssetId;
//       _prices[0] = 18_000 * 1e8;
//       _conf[0] = 0;

//       bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);
//     }

//     {
//       /*
//       AFTER T5

//       PLP VALUE (PLP TVL) = 1984030000000000000000000000000000000
//       assetIds	value
//       usdc	  99700000000000000000000000000000000 (1* 99700)
//       usdt	  0
//       dai	    0
//       weth	  0
//       wbtc	  1884330000000000000000000000000000000 (18_000 * 104.685)

//       PNL = 23290558980293305008147361345246745
//       Market Exposure     Price                                            AdaptivePrice                                    SIZE                                              PNL
//       WBTC   LONG         18000000000000000000000000000000000              20003333333333333320000000000000000              100000000000000000000000000000000000              -10014997500416597233794367605339120
//       JPY    LONG         7346297098947275625720855402                     7347521481797100166760944145                     100000000000000000000000000000000000              -16663889351774704215963998283398
//       WETH   SHORT        1000000000000000000000000000000000               1499750000000000001000000000000000               100000000000000000000000000000000000              +33322220370061676946157692948869263

//       Pending Borrowing Fee = 32905752433173900000000000000
                                
//          NEXT BORROWING Rate => (_assetClassConfig.baseBorrowingRate * _assetClassState.reserveValueE30 * intervals) / _plpTVL
//           BorrowingFee => (NEXT BORROWING RATE * _assetClassState.reserveValueE30) / RATE_PRECISION;
        
//       Pending Forex (JPY position) => 
//           NEXT BORROWING Rate  =  (300000000000000 * 900000000000000000000000000000000 * 2 ) / 1984030000000000000000000000000000000 = 272173303831
//           Borrowing Fee = 272173303831 * 900000000000000000000000000000000 / 1e18 => 244955973447900000000000000
                                                                                     
                                                                                     
//       Pending Crypto (WETH, WBTC position) =>
//           NEXT BORROWING Rate  =  (100000000000000 * 18000000000000000000000000000000000 * 2 ) / 1984030000000000000000000000000000000 = 1814488692207
//           Borrowing Fee =  1814488692207 * 18000000000000000000000000000000000 / 1e18 =>  32660796459726000000000000000
      

   
//       AUM = PLP VALUE - PNL + PENDING_BORROWING_FEE
//       AUM =  1984030000000000000000000000000000000 - (23290558980293305008147361345246745) + 32905752433173900000000000000
//       AUM =  1960739473925459128165752638654753255
//       PNL =  plpValue - aum + pendingBorrowingFee) negative of PNL means plp is profit

//       */
//       uint256 plpValueAfter = calculator.getPLPValueE30(false);
//       uint256 pendingBorrowingFeeAfter = calculator.getPendingBorrowingFeeE30();
//       uint256 aumAfter = calculator.getAUME30(false);
//       int256 pnlAfter = int256(plpValueAfter) - int256(aumAfter) + int256(pendingBorrowingFeeAfter);
//       assertEq(aumAfter, 1960739473925459128165752638654753255, "AUM After T5");
//       assertEq(plpValueAfter, 1984030000000000000000000000000000000, "PLP TVL After T5");
//       assertEq(pendingBorrowingFeeAfter, 32905752433173900000000000000, "Pending Borrowing Fee After T5");
//       assertEq(pnlAfter, 23290558980293305008147361345246745, "GLOBAL PNLE30 After T5");
//     }
//   }
// }
