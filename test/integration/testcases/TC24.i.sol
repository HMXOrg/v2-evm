// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// // Test cover Scenarios
// //   - LONG trader pay funding fee to funding fee reserve
// //   - LONG trader repay funding fee debts to PLP and pay remaining to funding fee reserve
// //   - SHORT trader receive funding fee from funding fee reserve
// //   - SHORT trader receive funding fee from PLP borrowing
// //   - SHORT trader receive funding fee from funding fee reserve and borrow fee from PLP
// //   - Deployer call withdrawSurplus function with contain surplus amount - must success
// //   - Deployer call withdrawSurplus function with no surplus amount - must revert

// contract TC24 is BaseIntTest_WithActions {
//   // TC24 - funding fee should be calculated correctly
//   function testCorrectness_TC24_TradeWithFundingFeeScenario() external {
//     // prepare token for wallet
//     {
//       // mint native token
//       vm.deal(BOB, 1 ether); // BOB acts as LP provider for protocol
//       vm.deal(ALICE, 1 ether); // ALICE acts as trader number 1
//       vm.deal(CAROL, 1 ether); // CAROL acts as trader number 2
//       vm.deal(DAVE, 1 ether); // DAVE acts as LP provider for protocol

//       // mint BTC
//       wbtc.mint(ALICE, 100 * 1e8);
//       wbtc.mint(BOB, 100 * 1e8);
//       wbtc.mint(CAROL, 100 * 1e8);
//       // mint USDC
//       usdc.mint(DAVE, 100_000 * 1e6);
//     }

//     // warp to block timestamp 1000
//     vm.warp(1000);

//     /**
//      * T0: Deployer trying to withdraw surplus and revert
//      */
//     {
//       // Then deployer can call withdraw surplus
//       vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_NoFundingFeeSurplus()"));
//       crossMarginHandler.withdrawFundingFeeSurplus(address(usdc), new bytes[](0));
//     }

//     /**
//      * T1: BOB provide liquidity as WBTC 50 tokens
//      */
//     {
//       // note: price has no changed0
//       addLiquidity(BOB, wbtc, 50 * 1e8, executionOrderFee, new bytes[](0), true);

//       _T1Assert();
//     }

//     /**
//      * T2: ALICE deposit BTC 200_000 USD at price 20,000 USD/WBTC
//      *     200_000 / 20_000 = 10 BTC
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       depositCollateral(ALICE, 0, wbtc, 10 * 1e8);

//       _T2Assert();
//     }

//     /**
//      * T3: ALICE market buy weth with 1_500_000 USD at price 1500 USD
//      *     Then Alice should has Long Position in WETH market
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       marketBuy(ALICE, 0, wethMarketIndex, 1_500_000 * 1e30, address(wbtc), new bytes[](0));

//       _T3Assert();
//     }

//     // ======================================================
//     // | LONG trader pay funding fee to funding fee reserve |
//     // ======================================================

//     /**
//      * T4: ALICE market buy weth with 500_000 USD at price 1500 USD
//      *     Then Alice's Long Position must be increased
//      */
//     {
//       skip(20 * 60); // time passed for 20 minutes

//       marketBuy(ALICE, 0, wethMarketIndex, 500_000 * 1e30, address(wbtc), new bytes[](0));

//       _T4Assert();
//     }

//     /**
//      * T5: Deployer see the surplus on funding fee and try to withdraw surplus to PLP
//      *     @note deployer must converts all funding fee reserves to stable token (USDC) before called withdraw surplus
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       _T5Assert1();
//       // Add USDC liquidity first to make plp have token to convert
//       addLiquidity(DAVE, usdc, 50_000 * 1e6, executionOrderFee, new bytes[](0), true);

//       _T5Assert2();

//       // Convert all tokens on funding fee reserve to be stable token
//       botHandler.convertFundingFeeReserve(address(usdc), new bytes[](0));

//       _T5Assert3();

//       // Then deployer can call withdraw surplus
//       crossMarginHandler.withdrawFundingFeeSurplus(address(usdc), new bytes[](0));

//       // After deployer call withdraw surplus and recalled again, function must be revert
//       vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_NoFundingFeeSurplus()"));
//       crossMarginHandler.withdrawFundingFeeSurplus(address(usdc), new bytes[](0));

//       _T5Assert4();
//     }

//     // =============================================================
//     // | SHORT trader receive funding fee from funding fee reserve |
//     // =============================================================

//     /**
//      * T6: CAROL deposit BTC 100_000 USD at price 20,000
//      *     100_000 / 20_000 = 5 BTC
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       depositCollateral(CAROL, 0, wbtc, 5 * 1e8);

//       _T6Assert();
//     }

//     /**
//      * T7: CAROL market sell weth with 200_000 USD at price 1500 USD
//      *     Then CAROL should has Short Position in WETH market
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       marketSell(CAROL, 0, wethMarketIndex, 200_000 * 1e30, address(wbtc), new bytes[](0));

//       _T7Assert();
//     }

//     /**
//      * T8: ALICE market buy weth with 100_000 USD at price 1500 USD
//      *     Then Alice's Long Position must be increased
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       _T8Assert1();

//       marketBuy(ALICE, 0, wethMarketIndex, 100_000 * 1e30, address(wbtc), new bytes[](0));

//       _T8Assert2();
//     }

//     /**
//      * T9: CAROL close sell position with 200_000 USD
//      *     CAROL must get funding fee from funding fee reserve
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       _T9Assert1();

//       marketBuy(CAROL, 0, wethMarketIndex, 200_000 * 1e30, address(wbtc), new bytes[](0));

//       _T9Assert2();
//     }

//     // =============================================================
//     // | SHORT trader receive funding fee from PLP                 |
//     // =============================================================

//     /**
//      * T10: CAROL market sell weth with 300_000 USD at price 1500 USD
//      *     Then CAROL should has new Short Position in WETH market
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       marketSell(CAROL, 0, wethMarketIndex, 300_000 * 1e30, address(wbtc), new bytes[](0));

//       _T10Assert();
//     }

//     /**
//      * T11: CAROL close sell position at price 1500 USD
//      *      Then CAROL should get funding fee from funding fee reserve
//      *      And funding fee reserve must borrow fee from PLP because reserve not enough to repay to CAROL
//      */
//     {
//       skip(60 * 60); // time passed for 1 hour

//       marketBuy(CAROL, 0, wethMarketIndex, 300_000 * 1e30, address(wbtc), new bytes[](0));

//       _T11Assert();
//     }

//     // ======================================================================================
//     // | SHORT trader receive funding fee from PLP borrowing                                |
//     // ======================================================================================

//     /**
//      * T12: CAROL open LONG position
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       marketSell(CAROL, 0, wethMarketIndex, 100_000 * 1e30, address(wbtc), new bytes[](0));

//       _T12Assert();
//     }

//     /**
//      * T13: CAROL close LONG position
//      *      AND get funding fee from PLP borrowing
//      */
//     {
//       skip(60 * 60); // time passed for 1 hour

//       marketBuy(CAROL, 0, wethMarketIndex, 100_000 * 1e30, address(wbtc), new bytes[](0));

//       _T13Assert();
//     }

//     // ======================================================================================
//     // | LONG trader repay funding fee debts to PLP and pay remaining to funding fee reserve |
//     // ======================================================================================

//     /**
//      * T14: ALICE close LONG position
//      *      AND pay borrowing debt from PLP
//      */
//     {
//       skip(60); // time passed for 60 seconds

//       marketSell(ALICE, 0, wethMarketIndex, 2_100_000 * 1e30, address(wbtc), new bytes[](0));

//       _T14Assert();
//     }
//   }

//   function _T1Assert() internal {
//     // When Bob provide 50 BTC as liquidity
//     assertTokenBalanceOf(BOB, address(wbtc), 50 * 1e8, "T1: ");

//     // Then Bob should pay fee for 0.3% = 0.15 BTC

//     // Assert PLP Liquidity
//     //    BTC = 50-0.15 = 49.85 (amount - fee)
//     assertPLPLiquidity(address(wbtc), 49.85 * 1e8, "T1: ");

//     // When PLP Token price is 1$
//     // Then PLP Token should Mint = 49.85 btc * 20,000 USD = 997_000 USD
//     //                            = 997_000 / 1 = 997_000 Tokens
//     assertPLPTotalSupply(997_000 * 1e18, "T1: ");

//     // Assert Fee distribution
//     // According from T0
//     // Vault's fees has nothing

//     // Then after Bob provide liquidity, then Bob pay fees
//     //    Add Liquidity fee
//     //      BTC - 0.15 btc
//     //          - distribute all to protocol fee

//     // In Summarize Vault's fees
//     //    BTC - protocol fee  = 0 + 0.15 = 0.15 btc
//     assertVaultsFees({ _token: address(wbtc), _fee: 0.15 * 1e8, _devFee: 0, _fundingFeeReserve: 0, _str: "T1: " });

//     // And accum funding fee
//     // accumFundingLong = 0
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 0, 0, "T1: ");

//     // Finally after Bob add liquidity Vault balance should be correct
//     // note: token balance is including all liquidity, dev fee and protocol fee
//     //    BTC - 50
//     assertVaultTokenBalance(address(wbtc), 50 * 1e8, "T1: ");
//   }

//   function _T2Assert() internal {
//     // When Alice deposit Collateral for 10 btc
//     // new Alice BTC balance of = old balance - out amount = 100 - 10 = 90 btc
//     assertTokenBalanceOf(ALICE, address(wbtc), 90 * 1e8, "T2: ");

//     // Then Vault btc's balance should be increased by 10
//     // Vault btc's balance = current amount + new adding amount = 50 + 10 = 60
//     assertVaultTokenBalance(address(wbtc), 60 * 1e8, "T2: ");

//     // And Alice's sub-account balances should be correct
//     //    BTC - 10
//     assertSubAccountTokenBalance(getSubAccount(ALICE, 0), address(wbtc), true, 10 * 1e8, "T2: ");

//     // And PLP total supply and Liquidity must not be changed
//     // note: data from T1
//     assertPLPTotalSupply(997_000 * 1e18, "T2: ");
//     assertPLPLiquidity(address(wbtc), 49.85 * 1e8, "T2: ");

//     // And Alice should not pay any fee
//     // note: vault's fees should be same with T1
//     assertVaultsFees({ _token: address(wbtc), _fee: 0.15 * 1e8, _devFee: 0, _fundingFeeReserve: 0, _str: "T2: " });

//     // And accum funding fee
//     // accumFundingLong = 0
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 0, 0, "T2: ");
//   }

//   function _T3Assert() internal {
//     // When Alice Buy WETH Market
//     // And Alice has no position
//     // Then it means Alice open new Long position
//     // Given increase size = 1_500_000 USD
//     // WETH Price = 1500 USD

//     // Then Check position Info
//     // Max scale skew       = 300_000_000 USD
//     // Market skew          = 0
//     // new Market skew      = 0 + 1_500_000
//     // Premium before       = 0 / 300_000_000 = 0
//     // Premium after        = 1_500_000 / 300_000_000 = 0.005
//     // Premium median       = (0 + 0.005) / 2 = 0.0025
//     // Adaptive price       = 1500 * (1 + 0.0025)
//     //                      = 1503.75

//     // WETH market IMF      = 1%
//     // WETH market MMF      = 0.5%
//     // Inc / Dec Fee        = 0.1%
//     // Position size        = 1_500_000 USD
//     // Open interest        = 1_500_000 USD / oracle price
//     //                      = 1_500_000 / 1500 = 1_000 ETH
//     // Avg price            = 1503.75 USD
//     // IMR                  = 1_500_000 * IMF = 1_500_000 * 1% = 15_000 USD
//     // MMR                  = 1_500_000 * MMF = 1_500_000 * 0.5% =  7_500 USD
//     // Reserve              = IMR * Max profit
//     //                      = 15_000 * 900%
//     //                      = 135_000
//     // Trading fee          = 1_500_000 * 0.1% = 1_500 USD

//     assertPositionInfoOf({
//       _subAccount: getSubAccount(ALICE, 0),
//       _marketIndex: wethMarketIndex,
//       _positionSize: int256(1_500_000 * 1e30),
//       _avgPrice: 1503.75 * 1e30,
//       _reserveValue: 135_000 * 1e30,
//       _realizedPnl: 0,
//       _entryBorrowingRate: 0,
//       _entryFundingRate: 0,
//       _str: "T3: "
//     });

//     // And accum funding fee
//     // accumFundingLong = 0
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 0, 0, "T3: ");
//   }

//   function _T4Assert() internal {
//     // When Alice Buy WETH Market more
//     // Market's Funding rate
//     // Funding rate         = -(Intervals * (Skew ratio * Max funding rate))
//     //                      = -((60 * 20 / 1) * (1_500_000 / 300_000_000 * 0.0004))
//     //                      = -0.0024
//     // Last Funding Time    = 1000 + 60 + 60 + 1200 = 2320
//     assertMarketFundingRate(wethMarketIndex, -0.0024 * 1e18, 2320, "T4: ");

//     // Funding fee          = (current rate - entry rate) * position size
//     //                      = (-0.0024 - 0) * 1_500_000
//     //                      = -3_600 USD (This mean LONG position must pay to SHORT position)
//     // Pay token amount(BTC)= 3_600 / 20_000 =  0.18 BTC;
//     assertFundingFeeReserve(address(wbtc), 0.18 * 1e8, "T4: ");

//     // Then Vault BTC's balance should still be the same as T2
//     assertVaultTokenBalance(address(wbtc), 60 * 1e8, "T4: ");

//     // And accum funding fee
//     // accumFundingLong  = Long position size * (current funding rate - last long funding rate)
//     //                   = 1_500_000 * (-0.0024 - 0) = -3600
//     // After Alice pay funding fee
//     //                   = 3600 - 3600 = 0
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 0, 0, "T4: ");
//   }

//   function _T5Assert1() internal {
//     // Assert before withdraw surplus
//     // PLP's liquidity = old amount + borrowing fee + trader's profit/loss
//     // ** in this test, we ignore calculating on those number and only focus on funding fee
//     // so magic number for borrowing fee + trader's profit/loss = 0.27322718 BTC
//     // new PLP's liquidity = 49.85 + 0.09322717999999952 = 49.94322718 WBTC
//     assertPLPLiquidity(address(wbtc), 49.94322718 * 1e8, "T5: ");
//   }

//   function _T5Assert2() internal {
//     // new PLP's liquidity = 50_000 USDC
//     assertPLPLiquidity(address(usdc), 50_000 * 1e6, "T5: ");
//   }

//   function _T5Assert3() internal {
//     // After convert WBTC to USDC
//     // WBTC = 0
//     // USDC = WBTC amount * WBTC Price / USDC Price
//     //      = 0.18 * 20_000 / 1
//     //      = 3_600 USDC
//     assertFundingFeeReserve(address(wbtc), 0 * 1e8, "T5: ");
//     assertFundingFeeReserve(address(usdc), 3_600 * 1e6, "T5: ");

//     // And USDC on PLP liquidity will be decreased
//     // USDC = 50_000 - 3_600 = 46_400 USDC
//     assertPLPLiquidity(address(usdc), 46_400 * 1e6, "T5: ");

//     // AND WBTC on PLP liquidity will be increased
//     // WBTC = 49.94322718 + 0.18 = 50.12322718
//     assertPLPLiquidity(address(wbtc), 50.12322718 * 1e8, "T5: ");
//   }

//   function _T5Assert4() internal {
//     // Assert PLP Liquidity
//     // When Deployer withdraw Surplus to PLP
//     // all funding fee reserve will consider as surplus
//     // according to Alice is the only one trader in the market
//     assertFundingFeeReserve(address(usdc), 0, "T5: ");
//     // PLP USDC = old + surplus amount
//     //          = 46_400 + 3_600
//     //          = 50000
//     assertPLPLiquidity(address(usdc), 50_000 * 1e6, "T5: ");
//   }

//   function _T6Assert() internal {
//     // When CAROL deposit Collateral for 5 btc
//     // new CAROL BTC balance of = old balance - out amount = 100 - 5 = 95 btc
//     assertTokenBalanceOf(CAROL, address(wbtc), 95 * 1e8, "T6: ");

//     // Then Vault btc's balance should be increased by 5
//     // Vault btc's balance = current amount + new adding amount = 60 + 5 = 65
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T6: ");

//     // And CAROL's sub-account balances should be correct
//     //    BTC - 5
//     assertSubAccountTokenBalance(getSubAccount(CAROL, 0), address(wbtc), true, 5 * 1e8, "T6: ");
//   }

//   function _T7Assert() internal {
//     // When CAROL Sell WETH Market
//     // Market's Funding rate
//     // new Funding rate     = -(Intervals * (Skew ratio * Max funding rate))
//     //                      = -((180 / 1) * (2_000_000 / 300_000_000 * 0.0004))
//     //                      = -0.00048
//     // Accum Funding Rate   = old + new = -0.0024 + (-0.00048) = -0.00288
//     // Last Funding Time    = 2320 + (60 + 60 + 60) = 2500
//     // Last Long Funding Rate = -0.002879999999999880
//     // Last Short Funding Rate = 0
//     assertMarketFundingRate(wethMarketIndex, -0.002879999999999880 * 1e18, 2500, "T7: ");

//     // Funding fee Reserve
//     // must still be 0 according to T6 that called withdraw surplus
//     assertFundingFeeReserve(address(wbtc), 0, "T7: ");

//     // Then Vault BTC's balance should still be the same as T6
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T7: ");

//     // And accum funding fee
//     // accumFundingLong  = Long position size * (current funding rate - last long funding rate)
//     //                   = 2_000_000 * (-0.002879999999999880 - (-0.0024))
//     //                   = -959.99999999976 USD
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 959.99999999976 * 1e30, 0, "T7: ");

//     // And entry funding rate of CAROL's Short position
//     // entryFundingRate     = currentFundingRate
//     //                      = -0.002879999999999880
//     assertEntryFundingRate(getSubAccount(CAROL, 0), wethMarketIndex, -0.002879999999999880 * 1e18, "T7: ");
//   }

//   function _T8Assert1() internal {
//     // Check Alice's sub account balance
//     // Ignore Trading fee, Borrowing fee, Trader's profit/loss on this test
//     assertSubAccountTokenBalance(getSubAccount(ALICE, 0), address(wbtc), true, 9.61032097 * 1e8, "T8: ");
//   }

//   function _T8Assert2() internal {
//     // When ALICE buy more on WETH Market
//     // Market's Funding rate
//     // new Funding rate     = -(Intervals * (Skew ratio * Max funding rate))
//     //                      = -((60 / 1) * ((2_000_000-200_000 )/ 300_000_000 * 0.0004))
//     //                      = -0.000144
//     // Accum Funding Rate   = old + new = -0.002879999999999880 + (-0.000144) = -0.00302399999999988
//     // Last Funding Time    = 2500 + 60 = 2560
//     // Last Long Funding Rate = -0.00302399999999988
//     // Last Short Funding Rate = -0.00302399999999988
//     assertMarketFundingRate(wethMarketIndex, -0.00302399999999988 * 1e18, 2560, "T8: ");

//     // And accum funding fee
//     // accumFundingLong  = old value + new value
//     //                   = -959.99999999976 + Long position size * (current funding rate - last long funding rate)
//     //                   = -959.99999999976 + (2_000_000 * (-0.00302399999999988 - (-0.002879999999999880)))
//     //                   = -1247.99999999976
//     // Alice pay long funding fee
//     //                   = 1247.99999999976 - 1247.99999999976 = 0
//     // accumFundingShort = old value + new value
//     //                   = 0 + Short position size * (current funding rate - last short funding rate)
//     //                   = 200_000 * (-0.00302399999999988 - (-0.002879999999999880)) =
//     //                   = -28.8
//     assertMarketAccumFundingFee(wethMarketIndex, 0, -28.8 * 1e30, "T8: ");

//     // Funding fee Reserve
//     // Funding fee Alice should be paid = FundingRate * Position Size
//     //                                  = (_sumFundingRate - _entryFundingRate) * Position Size
//     //                                  = (-0.00302399999999988 - (-0.0024)) * 2_000_000
//     //                                  = -1247.99999999976 USD
//     //                                  = -1247.99999999976 / 20_000 = -0.062399999999988 BTC
//     assertFundingFeeReserve(address(wbtc), 0.06239999 * 1e8, "T8: ");

//     // Then Vault BTC's balance should still be the same as T6
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T8: ");
//   }

//   function _T9Assert1() internal {
//     // check CAROL's BTC before by ignoring fee case
//     assertSubAccountTokenBalance(getSubAccount(CAROL, 0), address(wbtc), true, 4.99 * 1e8, "T9: ");
//   }

//   function _T9Assert2() internal {
//     // When CAROL Buy WETH Market
//     // Market's Funding rate
//     // new Funding rate     = -(Intervals * (Skew ratio * Max funding rate))
//     //                      = -((60 / 1) * ((2_100_000-200_000) / 300_000_000) * 0.0004) = -0.000152
//     //                      = -0.000152
//     // Accum Funding Rate   = old + new = -0.00302399999999988 + (-0.000152) = -0.00317599999999986
//     // Last Funding Time    = 2560 + 60 = 2620
//     // Last Long Funding Rate = -0.00317599999999986
//     // Last Short Funding Rate = -0.00317599999999986
//     assertMarketFundingRate(wethMarketIndex, -0.00317599999999986 * 1e18, 2620, "T9: ");

//     // And accum funding fee
//     // accumFundingLong  = old value + new value
//     //                   = 0 + Long position size * (current funding rate - last long funding rate)
//     //                   = 0 + (2_100_000 * (-0.00317599999999986 - (-0.00302399999999988)))
//     //                   = -319.199999999958
//     // accumFundingShort = old value + new value
//     //                   = -28.8 + Short position size * (current funding rate - last short funding rate)
//     //                   = -28.8 + 200_000 * (-0.00317599999999986 - (-0.00302399999999988))
//     //                   = -59.199999999996
//     // CAROL get funding fee reserve
//     //                   = 59.199999999996 - 59.199999999996 = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 319.199999999958 * 1e30, 0, "T9: ");

//     // Funding fee Reserve
//     // WBTC              = old balance - deduct amount
//     //                   = 0.06239999 - (59.199999999996 / 20_000) = 0.0594399900000002
//     //                   = 0.05944000
//     assertFundingFeeReserve(address(wbtc), 0.05944000 * 1e8, "T9: ");

//     // Then Vault BTC's balance should still be the same as T6
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T9: ");
//   }

//   function _T10Assert() internal {
//     // When CAROL Sell WETH Market
//     // Market's Funding rate
//     // new Funding rate     = -(60 * (Skew ratio * Max funding rate))
//     //                      = -((60 / 1) * (2_100_000 / 300_000_000 * 0.0004))
//     //                      = -0.000168
//     // Accum Funding Rate   = old + new = -0.00317599999999986 + -0.000168 = -0.00334399999999986
//     // Last Funding Time    = 2620 + 60 = 2680
//     assertMarketFundingRate(wethMarketIndex, -0.00334399999999986 * 1e18, 2680, "T10: ");

//     // Funding fee Reserve
//     // must still be as same as T9
//     assertFundingFeeReserve(address(wbtc), 0.05944000 * 1e8, "T10: ");
//     assertFundingFeeReserve(address(usdc), 0, "T10: ");

//     // Then Vault BTC's balance should still be the same as T6
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T10: ");

//     // And accum funding fee
//     // accumFundingLong  = old + (Long position size * (current funding rate - last long funding rate))
//     //                   = -319.199999999958 + (2_100_000 * (-0.00334399999999986 - (-0.00317599999999986)))
//     //                   = -319.199999999958 + (-352.8) = -671.999999999958 USD
//     // accumFundingShort = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 671.999999999958 * 1e30, 0, "T10: ");

//     // And entry funding rate of CAROL's Short position
//     // entryFundingRate     = currentFundingRate
//     //                      = -0.00334399999999986
//     assertEntryFundingRate(getSubAccount(CAROL, 0), wethMarketIndex, -0.00334399999999986 * 1e18, "T10: ");
//   }

//   function _T11Assert() internal {
//     // When CAROL Close Short Position
//     // Market's Funding rate
//     // new Funding rate     = -(3600 * (Skew ratio * Max funding rate))
//     //                      = -((3600 / 1) * ((2_100_000 - 300_000) / 300_000_000 * 0.0004))
//     //                      = -0.00864
//     // Accum Funding Rate   = old + new = -0.00334399999999986 + -0.00864 = -0.01198399999999986
//     // Last Funding Time    = 2680 + (3600) = 6280
//     assertMarketFundingRate(wethMarketIndex, -0.01198399999999986 * 1e18, 6280, "T11: ");

//     // Funding fee Reserve must no remaining tokens
//     assertFundingFeeReserve(address(wbtc), 0, "T11: ");
//     assertFundingFeeReserve(address(usdc), 0, "T11: ");

//     // And accum funding fee
//     // accumFundingLong  = old + (Long position size * (current funding rate - last long funding rate))
//     //                   = -671.999999999958 + (2_100_000 * (-0.01198399999999986 - (-0.00334399999999986))) =
//     //                   = -18815.999999999958
//     // accumFundingShort = old + (Short position size * (current funding rate - last short funding rate))
//     //                   = 0 + (300_000 * (-0.01198399999999986 - (-0.00334399999999986)))
//     //                   = -2592
//     // CAROL close position and get funding fee
//     //                   = -2592 + 2592 = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 18815.999999999958 * 1e30, 0, "T11: ");

//     // And PLP borrowing debt will be increased
//     // PLP borrowing debt = 2592 - (WBTC on funding fee reserve)
//     //                    = 2592 - (0.05944 * 20_000)
//     //                    = 1403.2
//     // Borrowing amount   = 2593 - 1189.8 = 1403.2
//     assertPLPDebt(1403.2 * 1e30, "T11: ");
//   }

//   function _T12Assert() internal {
//     // When CAROL Buy WETH Market
//     // Market's Funding rate
//     // new Funding rate     = -(Intervals * (Skew ratio * Max funding rate))
//     //                      = -((60 / 1) * ((2_100_000) / 300_000_000) * 0.0004)
//     //                      = -0.000168
//     // Accum Funding Rate   = old + new = -0.01198399999999986 + (-0.000168) = -0.01215199999999986
//     // Last Funding Time    = 6280 + (60) = 6340
//     assertMarketFundingRate(wethMarketIndex, -0.01215199999999986 * 1e18, 6340, "T12: ");

//     // And accum funding fee
//     // accumFundingLong  = old value + new value
//     //                   = -18815.999999999958 + Long position size * (current funding rate - last long funding rate)
//     //                   = -18815.999999999958 + (2_100_000 * (-0.01215199999999986 - (-0.01198399999999986)))
//     //                   = -19168.799999999958
//     // accumFundingShort = old value + new value
//     //                   = 0 + Short position size * (current funding rate - last short funding rate)
//     //                   = 0 + 0 * (-0.01215199999999986 - (-0.01198399999999986))
//     //                   = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 19168.799999999958 * 1e30, 0, "T12: ");

//     // Funding fee Reserve must still be zero
//     assertFundingFeeReserve(address(wbtc), 0, "T12: ");

//     // Then Vault BTC's balance should still be the same as T6
//     assertVaultTokenBalance(address(wbtc), 65 * 1e8, "T12: ");
//   }

//   function _T13Assert() internal {
//     // When CAROL Close Short Position
//     // Market's Funding rate
//     // new Funding rate     = -(3600 * (Skew ratio * Max funding rate))
//     //                      = -((3600 / 1) * ((2_100_000 - 100_000) / 300_000_000 * 0.0004))
//     //                      = -0.0096000000000000000001
//     // Accum Funding Rate   = old + new = -0.0121519999999 + -0.00960000000000000 = -0.0217519999999
//     // Last Funding Time    = 6340 + (3600) = 9940
//     assertMarketFundingRate(wethMarketIndex, -0.021751999999997460 * 1e18, 9940, "T13: ");

//     // Funding fee Reserve must no remaining tokens
//     assertFundingFeeReserve(address(wbtc), 0, "T13: ");
//     assertFundingFeeReserve(address(usdc), 0, "T13: ");

//     // And accum funding fee
//     // accumFundingLong  = old + (Long position size * (current funding rate - last long funding rate))
//     //                   = -19168.799999999958 + (2_100_000 * (-0.021751999999997460 - (-0.01215199999999986)))
//     //                   = -39328.799999994918
//     // accumFundingShort = old + (Short position size * (current funding rate - last short funding rate))
//     //                   = 0 + (100_000 * (-0.021751999999997460 - (-0.01215199999999986)))
//     //                   = -959.99999999976
//     // CAROL close position and get funding fee
//     //                   = -959.99999999976 + 959.99999999976 = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 39328.799999994918 * 1e30, 0, "T13: ");

//     // And PLP borrowing debt will be increased
//     // PLP borrowing debt = last debt value + new borrowing amount
//     //                    = 1403.2 + 959.99999999976 = 2363.19999999976
//     //                    = 2363.19999999976
//     assertPLPDebt(2363.19999999976 * 1e30, "T13: ");
//   }

//   function _T14Assert() internal {
//     // When ALICE Close Long Position
//     // Market's Funding rate
//     // new Funding rate     = -(60 * (Skew ratio * Max funding rate))
//     //                      = -((60 / 1) * ((2_100_000) / 300_000_000 * 0.0004))
//     //                      = -0.000168
//     // Accum Funding Rate   = old + new = -0.021751999999997460 + -0.000168 = -0.02191999999999746
//     // Last Funding Time    = 9940 + 60 = 10000
//     assertMarketFundingRate(wethMarketIndex, -0.02191999999999746 * 1e18, 10000, "T14: ");

//     // And accum funding fee
//     // accumFundingLong  = -39328.799999994918  + (Long position size * (current funding rate - last long funding rate))
//     //                   = -39328.799999994918  + (2_100_000 * (-0.02191999999999746 - (-0.021751999999997460)))
//     //                   = -39681.599999994918
//     // accumFundingShort = old + (Short position size * (current funding rate - last short funding rate))
//     //                   = 0 + (0 * (-0.02191999999999746 - (-0.021751999999997460)))
//     //                   = 0
//     // ALICE close position and get paid for funding fee
//     //                   = -39681.599999994918 + 39681.599999994918 = 0
//     assertMarketAccumFundingFee(wethMarketIndex, 0, 0, "T14: ");

//     // And Funding fee Reserve must be increased
//     // WBTC amount       = (funding fee value - PLP Debt) / BTC Price
//     //                   = (39681.599999994918 - 2363.19999999976) / 20_000
//     //                   = 1.8659199999997579 BTC
//     assertFundingFeeReserve(address(wbtc), 1.86591999 * 1e8, "T14: ");

//     // And PLP borrowing debt will be zero after Alice repay debt
//     assertPLPDebt(0, "T14: ");
//   }
// }
