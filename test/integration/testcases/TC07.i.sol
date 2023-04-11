// // // SPDX-License-Identifier: MIT
// // pragma solidity 0.8.18;

// // import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
// // import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
// // import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// // contract TC07 is BaseIntTest_WithActions {
// //   function testIntegration_WhenAdminAdjustIMF() external {
// //     /**
// //      * T0: Initialized state
// //      */
// //     vm.warp(block.timestamp + 1);
// //     uint8 SUB_ACCOUNT_ID = 1;
// //     address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);
// //     // Make LP contains some liquidity
// //     {
// //       bytes[] memory priceData = new bytes[](0);
// //       vm.deal(BOB, 1 ether); //deal with out of gas
// //       vm.deal(ALICE, 1 ether); //deal with out of gas
// //       wbtc.mint(BOB, 10 * 1e8);
// //       addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, true);
// //     }
// //     // Mint tokens to Alice
// //     {
// //       // Mint WETH token to ALICE
// //       weth.mint(ALICE, 8 * 1e18); // @note mint weth in value of 99_750 USD instead of 100_000 cause prevent decimal case (100_000 / 1_500 = 66.66666666666667 WETH)
// //       // Mint USDC token to ALICE
// //       usdc.mint(ALICE, 9_000 * 1e6);
// //       // Mint WBTC token to ALICE
// //       wbtc.mint(ALICE, 0.05 * 1e8);
// //       assertEq(weth.balanceOf(ALICE), 8 * 1e18, "WETH Balance Of");
// //       assertEq(usdc.balanceOf(ALICE), 9_000 * 1e6, "USDC Balance Of");
// //       assertEq(wbtc.balanceOf(ALICE), 0.05 * 1e8, "WBTC Balance Of");
// //     }

// //     /**
// //      * T1: Alice deposits 12,000(USD) WETH, 9,000(USD) USDC and 1,000(USD) WBTC as collaterals
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       // Before Alice start depositing, VaultStorage must has 0 amount of all collateral tokens
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(weth)), 0, "ALICE's WETH Balance");
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 0, "ALICE's USDC Balance");
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0, "ALICE's WBTC Balance");
// //       assertEq(weth.balanceOf(address(vaultStorage)), 0, "Vault's WETH Balance");
// //       assertEq(usdc.balanceOf(address(vaultStorage)), 0, "Vault's USDC Balance");
// //       assertEq(wbtc.balanceOf(address(vaultStorage)), 10 * 1e8, "Vault's WBTC Balance");
// //       // Alice deposits 12,000(USD) of WETH
// //       depositCollateral(ALICE, SUB_ACCOUNT_ID, MockErc20(address(weth)), 8 * 1e18);
// //       // Alice deposits 10,000(USD) of USDC
// //       depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);
// //       // Alice deposits 1,000(USD) of WBTC
// //       depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.05 * 1e8);
// //       // After Alice deposited all collaterals, VaultStorage must contain tokens
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(weth)), 8 * 1e18, "ALICE's WETH Balance");
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.05 * 1e8, "ALICE's WBTC Balance");
// //       assertEq(weth.balanceOf(address(vaultStorage)), 8 * 1e18, "Vault's WETH Balance");
// //       assertEq(usdc.balanceOf(address(vaultStorage)), 9_000 * 1e6, "Vault's USDC Balance");
// //       assertEq(wbtc.balanceOf(address(vaultStorage)), (0.05 + 10) * 1e8, "Vault's WBTC Balance");
// //       // After Alice deposited all collaterals, Alice must have no token left
// //       assertEq(weth.balanceOf(ALICE), 0, "WETH Balance Of");
// //       assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
// //       assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");
// //     }

// //     /**
// //      * T2: Alice sell short ETHUSD limit order at 450,000 USD (ETH price at 1500 USD)
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       uint256 sellSizeE30 = 100_000 * 1e30;
// //       address tpToken = address(wbtc);
// //       bytes[] memory priceData = new bytes[](0);
// //       // ALICE opens SHORT position with WETH Market Price = 1500 USD

// //       marketSell(
// //         ALICE,
// //         SUB_ACCOUNT_ID,
// //         wethMarketIndex,
// //         sellSizeE30,
// //         tpToken,
// //         tickPrices,
// //         publishTimeDiff,
// //         block.timestamp
// //       );

// //       // Alice's Equity must be upper IMR level
// //       // Equity = 19214.999999996664, IMR = 1000
// //       assertTrue(
// //         uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
// //         "ALICE's Equity > ALICE's IMR"
// //       );
// //     }

// //     /**
// //      * T3: ETHUSD priced up to 1,550 USD
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       //  Set Price for ETHUSD to 1,550 USD
// //       bytes32[] memory _assetIds = new bytes32[](4);
// //       _assetIds[0] = wethAssetId;
// //       _assetIds[1] = usdcAssetId;
// //       _assetIds[2] = daiAssetId;
// //       _assetIds[3] = wbtcAssetId;
// //       int64[] memory _prices = new int64[](4);
// //       _prices[0] = 1_550 * 1e8;
// //       _prices[1] = 1 * 1e8;
// //       _prices[2] = 1 * 1e8;
// //       _prices[3] = 20_000 * 1e8;
// //       uint64[] memory _confs = new uint64[](4);
// //       _confs[0] = 1000;
// //       _confs[1] = 1000;
// //       _confs[2] = 1000;
// //       _confs[3] = 1000;
// //       setPrices(_assetIds, _prices, _confs);

// //       // Alice's Equity must be upper IMR level
// //       // Equity = 16200.148339534511, IMR = 1000
// //       assertTrue(
// //         uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
// //         "ALICE's Equity > ALICE's IMR?"
// //       );
// //     }

// //     /**
// //      * T4: Alice withdraw 1000 collateral, (Equity still > IMR)
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       // Before Alice withdraw USDC
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
// //       assertEq(usdc.balanceOf(address(vaultStorage)), 9_000 * 1e6, "Vault's USDC Balance");
// //       assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");

//       // Alice withdraw 1000(USD) of USDC
//       // Expected that Alice can normally withdraw collateral
//       bytes[] memory priceData = new bytes[](0);
//       withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 1_000 * 1e6, priceData, executionOrderFee);

// //       // After Alice withdraw USDC
// //       assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), (9_000 - 1_000) * 1e6, "ALICE's USDC Balance");
// //       assertEq(usdc.balanceOf(address(vaultStorage)), (9_000 - 1_000) * 1e6, "Vault's WBTC Balance");
// //       assertEq(usdc.balanceOf(ALICE), 1_000 * 1e6, "USDC Balance Of");
// //     }

// //     /**
// //      * T5: Alice sell short ETHUSD position with Max Equity
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       uint256 sellSizeE30 = 1_314_600 * 1e30;
// //       address tpToken = address(wbtc);
// //       bytes[] memory priceData = new bytes[](0);
// //       // ALICE opens SHORT position with WETH Market Price = 1550 USD
// //       // Expect after sell position, will make Equity more closer to IMR level
// //       marketSell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, tpToken, priceData);

// //       // Alice's Free collateral must be almost zero
// //       assertEq(
// //         calculator.getFreeCollateral(SUB_ACCOUNT, 0, 0),
// //         2019923840855901124720000000000000, // 2019.923840855901124720000000000000 $
// //         "ALICE's free collateral is almost zero"
// //       );

// //       // Alice's Equity must be upper IMR level
// //       // Equity = 13046.248906439232, IMR = 13000
// //       assertTrue(
// //         uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
// //         "ALICE's Equity > ALICE's IMR?"
// //       );
// //     }

// //     /**
// //      * T6: Admin update IMF from 1% to 5%
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wethMarketIndex);
// //       // Check before admin start updating IMF number
// //       assertEq(_marketConfig.initialMarginFractionBPS, 100);
// //       _marketConfig.initialMarginFractionBPS = 500; // adjust IMF from 100 BPS => 500 BPS

// //       configStorage.setMarketConfig(wethMarketIndex, _marketConfig);

// //       // Check after admin updated IMF number
// //       IConfigStorage.MarketConfig memory _marketConfigAf = configStorage.getMarketConfigByIndex(wethMarketIndex);
// //       assertEq(_marketConfigAf.initialMarginFractionBPS, 500);
// //     }

//     /**
//      * T7: Alice cannot withdraw collateral cause now Alice's Equity < IMR
//      */
//     vm.warp(block.timestamp + 1);
//     {
//       // Alice withdraw 1(USD) of USDC
//       // Expect Alice can't withdraw collateral because Equity < IMR
//       bytes[] memory priceData = new bytes[](0);
//       // vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
//       withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 1 * 1e6, priceData, executionOrderFee);
//       // Alice's Equity must be lower IMR level
//       // Equity = 2850.5766353065096, IMR = 13000
//       assertTrue(
//         uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) < calculator.getIMR(SUB_ACCOUNT),
//         "ALICE's Equity < ALICE's IMR?"
//       );
//     }

// //     /**
// //      * T8: Admin update IMF from 5% to 1%
// //      */
// //     vm.warp(block.timestamp + 1);
// //     {
// //       IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wethMarketIndex);
// //       // Check before admin start updating IMF number
// //       assertEq(_marketConfig.initialMarginFractionBPS, 500);
// //       _marketConfig.initialMarginFractionBPS = 100; // adjust IMF from 500 BPS => 100 BPS

// //       configStorage.setMarketConfig(wethMarketIndex, _marketConfig);

// //       // Check after admin updated IMF number
// //       IConfigStorage.MarketConfig memory _marketConfigAf = configStorage.getMarketConfigByIndex(wethMarketIndex);
// //       assertEq(_marketConfigAf.initialMarginFractionBPS, 100);
// //     }

//     /**
//      * T9: Alice can withdraw collateral 10 USD
//      */
//     vm.warp(block.timestamp + 1);
//     {
//       // Before Alice withdraw USDC
//       assertEq(usdc.balanceOf(ALICE), 1000 * 1e6, "USDC Balance Of");
//       // Alice withdraw 10(USD) of USDC
//       bytes[] memory priceData = new bytes[](0);
//       withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 10 * 1e6, priceData, executionOrderFee);
//       // Alice's Equity must be lower IMR level
//       // Equity = 2850.5766353065096, IMR = 2600
//       assertTrue(
//         uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
//         "ALICE's Equity > IMR?"
//       );
//       // After Alice withdraw USDC
//       assertEq(usdc.balanceOf(ALICE), (1000 + 10) * 1e6, "USDC Balance Of");
//     }
//   }
// }
