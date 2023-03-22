// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

// import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

// import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

// import { console } from "forge-std/console.sol";

// contract TC05 is BaseIntTest_WithActions {
//   function testCorrectness_TC05() external {
//     bytes[] memory priceData = new bytes[](0);

//     // T0: Initialized state
//     {
//       //deal with out of gas
//       vm.deal(ALICE, 10 ether);
//       vm.deal(BOB, 10 ether);
//       /*
//        Alice balance
//        +-------+---------+
//        | Token | Balance |
//        +-------+---------+
//        | USDT  | 100,000 |
//        | WBTC  | 0.5     |
//        +-------+---------+
//        */
//       usdt.mint(ALICE, 100_000 * 1e6);
//       wbtc.mint(ALICE, 0.5 * 1e8);

//       /*
//        Alice balance
//        +-------+---------+
//        | Token | Balance |
//        +-------+---------+
//        | WBTC  | 10      |
//        +-------+---------+
//        */
//       wbtc.mint(BOB, 10 * 1e8);

//       assertEq(usdt.balanceOf(ALICE), 100_000 * 1e6, "T0: ALICE USDT Balance Of");
//       assertEq(wbtc.balanceOf(ALICE), 0.5 * 1e8, "T0: ALICE WBTC Balance Of");
//       assertEq(wbtc.balanceOf(BOB), 10 * 1e8, "T0: BOB WBTC Balance Of");
//     }

//     vm.warp(block.timestamp + 1);
//     {
//       // BOB add liquidity
//       addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, true);
//     }

//     vm.warp(block.timestamp + 1);
//     {
//       // Alice deposits 100,000(USD) of USDT
//       // depositCollateral(ALICE, 0, usdt, 100_000 * 1e6);
//       // Alice deposits 10,000(USD) of WBTC
//       depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);

//       /*
//        * +-------+---------+---------+------+---------------+
//        * | Asset | Balance |  Price  |  CF  |  Equity (USD) |
//        * +-------+---------+---------+------+---------------+
//        * | USDT  | 100,000 | 1       | 1    |    100,000.00 |
//        * | WBTC  | 0.05    | 20,000  | 0.8  |       800.00  |
//        * +-------+---------+---------+------+---------------+
//        * Equity: 108,000 USD
//        */
//       // assertEq(calculator.getCollateralValue(ALICE, 0, 0), 108_000 * 1e30);
//       assertEq(calculator.getCollateralValue(ALICE, 0, 0), 800 * 1e30);
//       // console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
//     }

//     vm.warp(block.timestamp + 1);
//     // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
//     {
//       bytes32[] memory _assetIds = new bytes32[](3);
//       _assetIds[0] = jpyAssetId;
//       _assetIds[1] = usdcAssetId;
//       _assetIds[2] = wbtcAssetId;
//       int64[] memory _prices = new int64[](3);
//       _prices[0] = 125 * 1e3;
//       _prices[1] = 1 * 1e8;
//       _prices[2] = 20_000 * 1e8;
//       uint64[] memory _confs = new uint64[](3);
//       _confs[0] = 0;
//       _confs[1] = 0;
//       _confs[2] = 0;
//       setPrices(_assetIds, _prices, _confs);

//       // buy
//       // IPerpStorage.GlobalMarket memory jpyMarket = perpStorage.getGlobalMarketByIndex(3);

//       bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);
//       // console.log("equity", uint256(calculator.getEquity(ALICE, 0, 0)));
//       marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(wbtc), priceData);

//       /*
//        * Global state
//        * | LongOI | ShortOI | Price (oracle) |
//        * |--------|---------|----------------|
//        * |   0    |    0    |      0.008     |
//        *
//        * Size: 100,000
//        * Entry price: 0.008133333333333333333333333333
//        * Reserve: 900
//        * Now: 4
//        * OI: 100,000 / 0.008 = 12,500,000
//        */

//       PositionTester02.PositionAssertionData memory _assetData = PositionTester02.PositionAssertionData({
//         size: 100_000 * 1e30,
//         avgPrice: 0.008133333333333333333333333333 * 1e30,
//         reserveValue: 900 * 1e30,
//         lastIncreaseTimestamp: 5
//       });
//       positionTester02.assertPosition(_positionId, _assetData);
//     }

//     // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.0048 USD. This makes Alice account went below her kill level
//     vm.warp(block.timestamp + (5 * MINUTES));
//     {
//       bytes32[] memory _assetIds = new bytes32[](3);
//       _assetIds[0] = jpyAssetId;
//       _assetIds[1] = usdcAssetId;
//       _assetIds[2] = wbtcAssetId;
//       int64[] memory _prices = new int64[](3);
//       _prices[0] = 125.40 * 1e3;
//       _prices[1] = 1 * 1e8;
//       _prices[2] = 20_000 * 1e8;
//       uint64[] memory _confs = new uint64[](3);
//       _confs[0] = 0;
//       _confs[1] = 0;
//       _confs[2] = 0;
//       setPrices(_assetIds, _prices, _confs);
//       /*
//        *
//        *
//        */
//       // IPerpStorage.GlobalMarket memory jpyMarket = perpStorage.getGlobalMarketByIndex(3);
//       // assertEq(calculator.getEquity(ALICE, 0, 0), 0);
//       // (bool isProfit, uint256 delta) = calculator.getDelta(
//       //   100_000 * 1e30,
//       //   true,
//       //   6666666666666666666666666667,
//       //   8133333333333333333333333333,
//       //   0
//       // );
//       // console.log("isProfit", isProfit);
//       // console.log("delta", delta);
//       // console.log("========================= Before");
//       // console.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
//       (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
//       console.log("pnl", uint256(-pnl));
//       console.log("fee", uint256(fee));
//       // console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
//       // console.log("before equity", uint256(calculator.getEquity(ALICE, 0, 0)));
//       // console.log("mmr", calculator.getMMR(ALICE));
//       //
//       // (int256 _unrealizedPnl, int256 _unrealizedFee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
//       // console.log("wbtc", address(wbtc));
//       // console.log("vaultStorage", address(vaultStorage));
//       // console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
//       // liquidate
//       // console.log("plp wbtc", vaultStorage.plpLiquidity(address(wbtc)));
//       // console.log("protocol fee", vaultStorage.protocolFees(address(wbtc)));
//       // console.log("dev fee", vaultStorage.devFees(address(wbtc)));
//       // console.log("========================= Liquidate");
//       liquidate(getSubAccount(ALICE, 0), priceData);
//       /*
//        * delta:
//        *
//        * |       loss        | trading | borrowing | funding | liquidation |
//        * |-------------------|---------|-----------|---------|-------------|
//        * | 697.4021646518535 |      30 |         0 |       0 |           5 |
//        * |         0.0348701 |  0.0015 |         0 |       0 |     0.00025 |
//        *
//        * total pay: 697.4021646518535 + 30 + 5 = 732.4021646518535 (0.0366201 BTC)
//        * trader balance = 0.04850000 - 0.0366201 = 0.0118799
//        * plp liquidity = 9.97 + 0.0348701 = 10.0048701
//        * dev fee = 0.0015 * 15% = 0.000225 | 0.000225 + 0.000225 = 0.00045
//        * protocol fee = 0.0015 * 85% = 0.001275 | 0.000225 + 0.000225 = 0.03255
//        * liquidation fee = 0.00025
//        */
//       assertEq(vaultStorage.traderBalances(ALICE, address(wbtc)), 0.0118799 * 1e8);
//       assertEq(vaultStorage.plpLiquidity(address(wbtc)), 10.0048701 * 1e8);
//       assertEq(vaultStorage.devFees(address(wbtc)), 0.00045 * 1e8);
//       assertEq(vaultStorage.protocolFees(address(wbtc)), 0.032550 * 1e8);
//       assertEq(vaultStorage.traderBalances(BOT, address(wbtc)), 0.00025 * 1e8);
//       assertEq(perpStorage.getNumberOfSubAccountPosition(ALICE), 0);

//       // console.log("========================= After");
//       // console.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
//       // (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
//       // console.log("pnl", uint256(-pnl));
//       // console.log("fee", uint256(fee));
//       // console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
//       // Alice 0.04850000
//       // delta 0.8 - 0.8076611290608315842681630887 = 697.4021646518535
//       // fee 30 + 5 + 0 = 35
//       // 697.4021646518535 + 35 = 732.4021646518535
//       // 0.03662010823259267 BTC
//       // 100000000
//       // 01187989
//       // 0.04850000 - 0.03662010823259267 0.01187989
//       // 0.47
//       // 697.4021646518535 + 5 =
//       // 0.047 - 0.03512010 = 0.01187980
//       // 0.04700000
//       // 0.03512010
//       // 0.01187990
//       // assertEq(vaultStorage.traderBalances(ALICE, address(wbtc)), 0.01187990 * 1e8);
//       // trading fee: 30
//       // borrowing fee: 0
//       // fundind fee: 0
//       // liquidation fee: 5
//       // delta: -697.4021646518535

//       // plp:697.4021646518535
//       //    : 0.03487010
//       // 9.97+0.03487010 = 10.0048701

//       //    : 0.0015*85% = 0.001275
//       // assertEq(vaultStorage.plpLiquidity(address(wbtc)), 10.0048701 * 1e8);
//       // 30*15% = 4.5
//       // 4.5 / 20000 = 0.000225
//       // 0.000225 + 0.000225 = 0.00045
//       // assertEq(vaultStorage.devFees(address(wbtc)), 0.00045 * 1e8);
//       // 30*85% = 25.5
//       // 25.5 / 20000 = 0.001275
//       // 0.03127500 + 0.001275 = 0.032550
//       // assertEq(vaultStorage.protocolFees(address(wbtc)), 0.032550 * 1e8);
//       // 30
//       // 5 / 20000 = 0.00025
//       // assertEq(vaultStorage.traderBalances(BOT, address(wbtc)), 0.00025 * 1e8);
//       // assertEq(perpStorage.getNumberOfSubAccountPosition(ALICE), 0);
//       //
//       //
//       // console.log("after equity", uint256(calculator.getEquity(ALICE, 0, 0)));
//     }
//   }
// }
