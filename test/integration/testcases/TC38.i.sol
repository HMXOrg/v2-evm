// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

import { console2 } from "forge-std/console2.sol";

contract TC38 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC38() external {
    bytes[] memory priceData = new bytes[](0);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);
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
      wbtc.mint(ALICE, 5 * 1e8);

      /*
       Alice balance
       +-------+---------+
       | Token | Balance |
       +-------+---------+
       | WBTC  | 10      |
       +-------+---------+
       */
      wbtc.mint(BOB, 100 * 1e8);
      usdc.mint(BOB, 1_000_000 * 1e6);
    }

    {
      // BOB add liquidity
      addLiquidity(BOB, usdc, 1_000_000 * 1e6, executionOrderFee, priceData, true);
    }

    {
      // Alice deposits 10,000(USD) of WBTC
      // depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
      // depositCollateral(ALICE, 1, wbtc, 1 * 1e8);
      depositCollateral(ALICE, 0, usdt, 1_000 * 1e6);
    }

    // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
    {
      updatePriceData = new bytes[](4);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);
      updatePriceData[3] = _createPriceFeedUpdateData(wethAssetId, 1_500 * 1e8, 0);

      // buy
      // bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);

      marketBuy(ALICE, 0, wbtcMarketIndex, 10_000 * 1e30, address(wbtc), updatePriceData);
      marketSell(ALICE, 0, wethMarketIndex, 10_000 * 1e30, address(wbtc), updatePriceData);
      // marketSell(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(wbtc), updatePriceData);
      // marketSell(ALICE, 0, wbtcMarketIndex, 200_000 * 1e30, address(wbtc), updatePriceData);
      // marketBuy(ALICE, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), updatePriceData);
    }

    vm.warp(block.timestamp + (100 * SECONDS));
    {
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      _assetIds[3] = wethAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 22_000 * 1e8;
      _prices[3] = 1_650 * 1e8;
      uint64[] memory _confs = new uint64[](4);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      _confs[3] = 0;
      setPrices(_assetIds, _prices, _confs);

      console2.log("=======================================");
      // uint256 collateral = calculator.getCollateralValue(ALICE, 0, 0);
      // console2.log(" - collateral", collateral);
      // (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
      // console2.log(" - pnl", pnl);
      // console2.log(" - fee", fee);
      int256 equity = calculator.getEquity(ALICE, 0, 0);
      console2.log("equity", equity);
      // uint256 feeCollateral = calculator.getFreeCollateral(ALICE, 0, 0);
      // console2.log("feeCollateral", feeCollateral);
      console2.log("=======================================");
    }

    vm.warp(block.timestamp + (15 * MINUTES));
    {
      updatePriceData = new bytes[](4);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 22_000 * 1e8, 0);
      updatePriceData[3] = _createPriceFeedUpdateData(wethAssetId, 1_650 * 1e8, 0);
      marketBuy(ALICE, 0, wethMarketIndex, 10_000 * 1e30, address(usdc), updatePriceData);
    }

    vm.warp(block.timestamp + (100 * SECONDS));
    {
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      _assetIds[3] = wethAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 22_000 * 1e8;
      _prices[3] = 1_650 * 1e8;
      uint64[] memory _confs = new uint64[](4);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      _confs[3] = 0;
      setPrices(_assetIds, _prices, _confs);

      console2.log("=======================================");
      // uint256 collateral = calculator.getCollateralValue(ALICE, 0, 0);
      // console2.log(" - collateral", collateral);
      // (int256 pnl, int256 fee) = calculator.getUnrealizedPnlAndFee(ALICE, 0, 0);
      // console2.log(" - pnl", pnl);
      // console2.log(" - fee", fee);
      int256 equity = calculator.getEquity(ALICE, 0, 0);
      console2.log("equity", equity);
      // uint256 feeCollateral = calculator.getFreeCollateral(ALICE, 0, 0);
      // console2.log("feeCollateral", feeCollateral);
      console2.log("=======================================");
    }

    vm.warp(block.timestamp + (15 * MINUTES));
    {
      updatePriceData = new bytes[](4);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 22_000 * 1e8, 0);
      updatePriceData[3] = _createPriceFeedUpdateData(wethAssetId, 1_650 * 1e8, 0);
      marketBuy(ALICE, 0, wethMarketIndex, 10_000 * 1e30, address(usdc), updatePriceData);
    }

    // {
    //   updatePriceData = new bytes[](3);
    //   updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
    //   updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
    //   updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 19_500 * 1e8, 0);
    //   marketSell(ALICE, 0, wbtcMarketIndex, 40_000 * 1e30, address(usdc), updatePriceData);
    // }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.007945967421533571712355979340 USD. This makes Alice account went below her kill level
    // vm.warp(block.timestamp + (24 * HOURS));
    // {
    //   updatePriceData = new bytes[](3);
    //   updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125.85 * 1e3, 0);
    //   updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
    //   updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_100 * 1e8, 0);

    //   liquidate(getSubAccount(ALICE, 0), updatePriceData);
    //   /*
    //    *
    //    * |       loss        |   trading   |      borrowing     |      funding     | liquidation | unit |
    //    * |-------------------|-------------|--------------------|------------------|-------------|------|
    //    * |            500.00 |         100 | 1466.7524962948546 | -115.19999999712 |           5 |  USD |
    //    * |        0.02487562 |  0.00497512 |         0.07297276 |      -0.00573134 |  0.00024875 |  BTC |
    //    *
    //    * total pay: 0.00497512 + 0.07297276 + 0.00024875 = 0.07819663
    //    * total receive: 0.02487562 + 0.00573134 = 0.03060696
    //    * trader balance = 0.095 + 0.03060696 - 0.07819663 = 0.04741033
    //    * dev fee = (0.00497512 * 15%) + (0.07297276 * 15%) = 0.00074626 + 0.01094591 = 0.01169217 | 0.001575 + 0.01169217 = 0.01326717
    //    * plp liquidity = 0.07297276 - 0.01094591 = 0.06202685 | 49.85 + 0.06202685 - 0.02487562 - 0.00573134 = 49.88141989
    //    * protocol fee = 0.00497512 - 0.00074626 = 0.00422886 | 0.158925 + 0.00422886 = 0.16315386
    //    * liquidation fee = 0.00025
    //    */
    //   assertSubAccountTokenBalance(ALICE, address(wbtc), true, 0.04741033 * 1e8);
    //   assertVaultsFees(address(wbtc), 0.16315386 * 1e8, 0.01326717 * 1e8, 0 * 1e8);
    //   assertPLPLiquidity(address(wbtc), 49.88141989 * 1e8);
    //   assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00024875 * 1e8);
    //   assertNumberOfPosition(ALICE, 0);
    // }
  }
}
