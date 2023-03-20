// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

import { console } from "forge-std/console.sol";

contract TC05 is BaseIntTest_WithActions {
  function testCorrectness_TC05() external {
    bytes[] memory priceData = new bytes[](0);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      /*
       Alice balance
       +-------+---------+
       | Token | Balance |
       +-------+---------+
       | USDT  | 100,000 |
       | WBTC  | 0.5     |
       +-------+---------+
       */
      usdt.mint(ALICE, 100_000 * 1e6);
      wbtc.mint(ALICE, 0.5 * 1e8);

      /*
       Alice balance
       +-------+---------+
       | Token | Balance |
       +-------+---------+
       | WBTC  | 10      |
       +-------+---------+
       */
      wbtc.mint(BOB, 10 * 1e8);

      assertEq(usdt.balanceOf(ALICE), 100_000 * 1e6, "T0: ALICE USDT Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.5 * 1e8, "T0: ALICE WBTC Balance Of");
      assertEq(wbtc.balanceOf(BOB), 10 * 1e8, "T0: BOB WBTC Balance Of");
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 100,000(USD) of USDT
      // depositCollateral(ALICE, 0, usdt, 100_000 * 1e6);
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);

      /*
       * +-------+---------+---------+------+---------------+
       * | Asset | Balance |  Price  |  CF  |  Equity (USD) |
       * +-------+---------+---------+------+---------------+
       * | USDT  | 100,000 | 1       | 1    |    100,000.00 |
       * | WBTC  | 0.05    | 20,000  | 0.8  |       800.00  |
       * +-------+---------+---------+------+---------------+
       * Equity: 108,000 USD
       */
      // assertEq(calculator.getCollateralValue(ALICE, 0, 0), 108_000 * 1e30);
      assertEq(calculator.getCollateralValue(ALICE, 0, 0), 800 * 1e30);
      console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 20_000 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      // buy
      // IPerpStorage.GlobalMarket memory jpyMarket = perpStorage.getGlobalMarketByIndex(3);
      // console.log("longOpenInterest", jpyMarket.longOpenInterest);
      // console.log("shortOpenInterest", jpyMarket.shortOpenInterest);

      bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);
      // console.log("equity", uint256(calculator.getEquity(ALICE, 0, 0)));
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(wbtc), priceData);

      /*
       * Global state
       * | LongOI | ShortOI | Price (oracle) |
       * |--------|---------|----------------|
       * |   0    |    0    |      0.008     |
       *
       * Size: 100,000
       * Entry price: 0.008133333333333333333333333333
       * Reserve: 900
       * Now: 4
       * OI: 100,000 / 0.008 = 12,500,000
       */

      // PositionTester02.PositionAssertionData memory _assetData = PositionTester02.PositionAssertionData({
      //   size: 100_000 * 1e30,
      //   avgPrice: 0.008133333333333333333333333333 * 1e30,
      //   reserveValue: 900 * 1e30,
      //   lastIncreaseTimestamp: 4,
      //   openInterest: 12_500_000 * 1e3
      // });
      // positionTester02.assertPosition(_positionId, _assetData);
    }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.0048 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (20 * MINUTES));
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125.85 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 20_000 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);
      /*
       *
       *
       */
      // IPerpStorage.GlobalMarket memory jpyMarket = perpStorage.getGlobalMarketByIndex(3);
      // console.log("longOpenInterest", jpyMarket.longOpenInterest);
      // console.log("shortOpenInterest", jpyMarket.shortOpenInterest);
      // assertEq(calculator.getEquity(ALICE, 0, 0), 0);
      // (bool isProfit, uint256 delta) = calculator.getDelta(
      //   100_000 * 1e30,
      //   true,
      //   6666666666666666666666666667,
      //   8133333333333333333333333333,
      //   0
      // );
      // console.log("isProfit", isProfit);
      // console.log("delta", delta);
      console.log("========================= Before");
      console.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
      // (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
      // console.log("pnl", uint256(-pnl));
      // console.log("fee", uint256(fee));
      console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
      console.log("before equity", uint256(calculator.getEquity(ALICE, 0, 0)));
      // console.log("mmr", calculator.getMMR(ALICE));
    }
    // console.log("wbtc", address(wbtc));
    // console.log("vaultStorage", address(vaultStorage));
    // console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
    // liquidate
    liquidate(getSubAccount(ALICE, 0), priceData);
    console.log("========================= After");
    console.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
    // (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
    // console.log("pnl", uint256(-pnl));
    // console.log("fee", uint256(fee));
    console.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
    console.log("after equity", uint256(calculator.getEquity(ALICE, 0, 0)));
  }
}
