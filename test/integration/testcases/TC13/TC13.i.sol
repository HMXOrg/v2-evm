// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// import { console2 } from "forge-std/console2.sol";

// contract TC13 is BaseIntTest_WithActions {
//   bytes[] internal updatePriceData;

//   // TC13 - Collateral & Trade management with bad price
//   function testCorrectness_TC13_CollateralManage_And_TradeWithBadPrice() external {
//     // ### Scenario: Prepare environment

//     // mint native token
//     vm.deal(BOB, 1 ether);
//     vm.deal(ALICE, 1 ether);
//     vm.deal(FEEVER, 1 ether);

//     // mint BTC
//     wbtc.mint(ALICE, 100 * 1e8);
//     wbtc.mint(BOB, 100 * 1e8);

//     // mint USDC
//     usdc.mint(ALICE, 20_000 * 1e6);
//     usdc.mint(BOB, 10_000 * 1e6);

//     // warp to block timestamp 1000
//     vm.warp(1000);

//     address _aliceSubAccount0 = getSubAccount(ALICE, 0);
//     address _bobSubAccount0 = getSubAccount(BOB, 0);

//     // ### Scenario: Prepare environment
//     // Given Btc price is 20,000 USD
//     // And WETH price is 1,500 USD
//     // And JPY price is 136.123 USDJPY
//     // And USDC price is 1 USD

//     updatePriceData = new bytes[](4);
//     updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1500 * 1e8, 0);
//     updatePriceData[1] = _createPriceFeedUpdateData(wbtcAssetId, 20000 * 1e8, 0);
//     updatePriceData[2] = _createPriceFeedUpdateData(jpyAssetId, 136.123 * 1e3, 0);
//     updatePriceData[3] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);

//     // And Bob provide 1 btc as liquidity
//     addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, updatePriceData, true);

//     assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8, "Bob's wbtc: ");

//     // ### Scenario: Trader deposit normally
//     // When Alice deposit collateral 1 btc
//     depositCollateral(ALICE, 0, wbtc, 1 * 1e8);
//     // And Alice deposit collateral 10000 usdc
//     depositCollateral(ALICE, 0, usdc, 10_000 * 1e6);
//     // And Bob deposit collateral 2000 usdc
//     depositCollateral(BOB, 0, usdc, 2_000 * 1e6);
//     {
//       // Then Alice's balances should be corrected
//       assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 1 * 1e8, "Alice's wbtc: ");
//       assertSubAccountTokenBalance(_aliceSubAccount0, address(usdc), true, 10_000 * 1e6, "Alice's usdc: ");

//       assertTokenBalanceOf(ALICE, address(wbtc), 99 * 1e8, "Alice's wbtc: ");
//       assertTokenBalanceOf(ALICE, address(usdc), 10_000 * 1e6, "Alice's usdc: ");

//       // And Bob's balances should be corrected
//       assertSubAccountTokenBalance(_bobSubAccount0, address(usdc), true, 2_000 * 1e6, "Bob's usdc: ");
//       assertTokenBalanceOf(BOB, address(usdc), 8_000 * 1e6, "Bob's usdc: ");
//     }

//     // time passed 15 seconds
//     skip(15);

//     // ### Scenario: BTC has bad price
//     // When found bad price in BTC
//     // note: max confidential to make bad price
//     updatePriceData[1] = _createPriceFeedUpdateData(wbtcAssetId, 20000 * 1e8, type(uint64).max / 1e6);
//     updatePriceFeeds(updatePriceData);

//     // When Alice deposit more 0.1 btc
//     depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
//     {
//       // Then Alice's balances should be corrected
//       assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 1.1 * 1e8, "Alice's wbtc: ");
//       assertTokenBalanceOf(ALICE, address(wbtc), 98.9 * 1e8, "Alice's wbtc: ");

//       // usdc balance should not be affected
//       assertSubAccountTokenBalance(_aliceSubAccount0, address(usdc), true, 10_000 * 1e6, "Alice's usdc: ");
//       assertTokenBalanceOf(ALICE, address(usdc), 10_000 * 1e6, "Alice's usdc: ");
//     }
//     // When Alice withdraw 0.1 btc
//     // Then Revert PythAdapter_ConfidenceRatioTooHigh
//     vm.expectRevert(abi.encodeWithSignature("PythAdapter_ConfidenceRatioTooHigh()"));
//     withdrawCollateral(ALICE, 0, wbtc, 0.1 * 1e8, updatePriceData);

//     // When Alice withdraw 500 USDC
//     // Then Revert PythAdapter_ConfidenceRatioTooHigh
//     vm.expectRevert(abi.encodeWithSignature("PythAdapter_ConfidenceRatioTooHigh()"));
//     withdrawCollateral(ALICE, 0, usdc, 500 * 1e6, updatePriceData);

//     // When BOB withdraw 500 USDC
//     withdrawCollateral(BOB, 0, usdc, 500 * 1e6, updatePriceData);
//     {
//       // Then Bob's balances should be corrected
//       assertSubAccountTokenBalance(_bobSubAccount0, address(usdc), true, 1_500 * 1e6, "Bob's usdc: ");
//       assertTokenBalanceOf(BOB, address(usdc), 8_500 * 1e6, "Bob's usdc: ");
//     }

//     // timepassed 15 seconds
//     skip(15);

//     // ### Scenario: BTC price comeback
//     // When BTC price is healthy
//     updatePriceData[1] = _createPriceFeedUpdateData(wbtcAssetId, 20000 * 1e8, 0);
//     // And Alice withdraw 0.1 btc
//     withdrawCollateral(ALICE, 0, wbtc, 0.1 * 1e8, updatePriceData);
//     {
//       // Then Alice's balances should be corrected
//       assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 1 * 1e8, "Alice's wbtc: ");
//       assertTokenBalanceOf(ALICE, address(wbtc), 99 * 1e8, "Alice's wbtc: ");
//     }

//     // And Bob deposit 0.1 btc
//     depositCollateral(BOB, 0, wbtc, 0.1 * 1e8);
//     {
//       // Then Bob's balances should be corrected
//       assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.1 * 1e8, "Bob's wbtc: ");
//       assertTokenBalanceOf(BOB, address(wbtc), 98.9 * 1e8, "Bob's wbtc: ");

//       assertSubAccountTokenBalance(_bobSubAccount0, address(usdc), true, 1_500 * 1e6, "Bob's usdc: ");
//       assertTokenBalanceOf(BOB, address(usdc), 8_500 * 1e6, "Bob's usdc: ");
//     }

//     // ### Scenario: Trader do trade normally
//     // When Alice buy BTC 100 USD
//     marketBuy(ALICE, 0, wbtcMarketIndex, 100 * 1e30, address(wbtc), updatePriceData);
//     // And Alice sell at JPY 10000 USD
//     marketSell(ALICE, 0, jpyMarketIndex, 10_000 * 1e30, address(wbtc), updatePriceData);
//     {
//       assertPositionInfoOf({
//         _subAccount: _aliceSubAccount0,
//         _marketIndex: wbtcMarketIndex,
//         _positionSize: int256(100 * 1e30),
//         _avgPrice: 20000.003333333333333333333333320000 * 1e30,
//         _reserveValue: 9 * 1e30,
//         _realizedPnl: 0,
//         _entryBorrowingRate: 0,
//         _entryFundingRate: 0,
//         _str: "Alice's BTC position"
//       });

//       assertPositionInfoOf({
//         _subAccount: _aliceSubAccount0,
//         _marketIndex: jpyMarketIndex,
//         _positionSize: -int256(10_000 * 1e30),
//         _avgPrice: 0.007346174660662293171127093387 * 1e30,
//         _reserveValue: 90 * 1e30,
//         _realizedPnl: 0,
//         _entryBorrowingRate: 0,
//         _entryFundingRate: 0,
//         _str: "Alice's JPY position"
//       });
//     }

//     // ### Scenario: JPY has bad price
//     // When found bad price in JPY
//     updatePriceData[2] = _createPriceFeedUpdateData(jpyAssetId, 136.123 * 1e3, type(uint64).max / 1e6);
//     // And Alice try to close JPY's position
//     // Then Revert PythAdapter_ConfidenceRatioTooHigh
//     marketBuy(
//       ALICE,
//       0,
//       jpyMarketIndex,
//       10_000 * 1e30,
//       address(wbtc),
//       updatePriceData,
//       "PythAdapter_ConfidenceRatioTooHigh()"
//     );
//     {
//       // And Alice's JPY position and balance should not be affected
//       assertPositionInfoOf({
//         _subAccount: _aliceSubAccount0,
//         _marketIndex: jpyMarketIndex,
//         _positionSize: -int256(10_000 * 1e30),
//         _avgPrice: 0.007346174660662293171127093387 * 1e30,
//         _reserveValue: 90 * 1e30,
//         _realizedPnl: 0,
//         _entryBorrowingRate: 0,
//         _entryFundingRate: 0
//       });
//     }

//     // And Alice try close BTC's position
//     // Then Revert PythAdapter_ConfidenceRatioTooHigh because Alice's has JPY's position
//     marketSell(
//       ALICE,
//       0,
//       wbtcMarketIndex,
//       20 * 1e30,
//       address(wbtc),
//       updatePriceData,
//       "PythAdapter_ConfidenceRatioTooHigh()"
//     );

//     // When Bob buy position at JPY 20000 USD
//     // Then Revert PythAdapter_ConfidenceRatioTooHigh
//     marketBuy(
//       BOB,
//       0,
//       jpyMarketIndex,
//       20_000 * 1e30,
//       address(wbtc),
//       updatePriceData,
//       "PythAdapter_ConfidenceRatioTooHigh()"
//     );

//     // But Bob try buy BTC 300 USD
//     marketBuy(BOB, 0, wbtcMarketIndex, 300 * 1e30, address(wbtc), updatePriceData);
//     {
//       // Then Bob's position should be corrected
//       assertPositionInfoOf({
//         _subAccount: _bobSubAccount0,
//         _marketIndex: wbtcMarketIndex,
//         _positionSize: int256(300 * 1e30),
//         _avgPrice: 20000.01666666666666666666666666 * 1e30,
//         _reserveValue: 27 * 1e30,
//         _realizedPnl: 0,
//         _entryBorrowingRate: 0,
//         _entryFundingRate: 0
//       });
//     }

//     // time passed 15 seconds
//     skip(15);

//     // ### Scenario: JPY price comeback
//     // When JPY price is healthy
//     updatePriceData[2] = _createPriceFeedUpdateData(jpyAssetId, 136.123 * 1e3, 0);
//     updatePriceFeeds(updatePriceData);

//     // And Alice close JPY position
//     marketBuy(ALICE, 0, jpyMarketIndex, 10_000 * 1e30, address(wbtc), updatePriceData);
//     {
//       // Then Alice's positions and balance should be corrected
//       assertPositionInfoOf({
//         _subAccount: _aliceSubAccount0,
//         _marketIndex: jpyMarketIndex,
//         _positionSize: 0,
//         _avgPrice: 0,
//         _reserveValue: 0,
//         _realizedPnl: 0,
//         _entryBorrowingRate: 0,
//         _entryFundingRate: 0
//       });
//     }
//   }
// }
