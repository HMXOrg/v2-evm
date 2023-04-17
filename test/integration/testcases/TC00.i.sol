// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { console2 } from "forge-std/console2.sol";

contract TC00 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData = new bytes[](0);

  function testCorrectness_TC00() external {
    {
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      usdt.mint(ALICE, 100_000 * 1e6);
      wbtc.mint(ALICE, 5 * 1e8);

      wbtc.mint(BOB, 100 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    {
      addLiquidity(BOB, wbtc, 50 * 1e8, executionOrderFee, updatePriceData, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, usdt, 1_205 * 1e6);
      // depositCollateral(ALICE, 1, usdt, 1 * 1e8);
    }

    {
      updatePriceData = new bytes[](3);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);

      // buy
      marketBuy(ALICE, 0, jpyMarketIndex, 300_000 * 1e30, address(wbtc), updatePriceData);
      // marketBuy(ALICE, 0, wbtcMarketIndex, 30_000 * 1e30, address(wbtc), updatePriceData);
      console2.log("size", perpStorage.getPositionById(getPositionId(ALICE, 0, wbtcMarketIndex)).positionSizeE30);
      console2.log("size", perpStorage.getPositionById(getPositionId(ALICE, 0, jpyMarketIndex)).positionSizeE30);
      console2.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
      console2.log("equity", calculator.getEquity(ALICE, 0, 0));
      console2.log("free collateral", calculator.getFreeCollateral(ALICE, 0, 0));

      marketBuy(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(wbtc), updatePriceData);
      // marketBuy(ALICE, 0, wbtcMarketIndex, 69_999 * 1e30, address(wbtc), updatePriceData);
      // marketBuy(ALICE, 0, wbtcMarketIndex, 70_000 * 1e30, address(wbtc), updatePriceData);
      console2.log("size", perpStorage.getPositionById(getPositionId(ALICE, 0, wbtcMarketIndex)).positionSizeE30);
      console2.log("size", perpStorage.getPositionById(getPositionId(ALICE, 0, jpyMarketIndex)).positionSizeE30);
      console2.log("collateral", calculator.getCollateralValue(ALICE, 0, 0));
      console2.log("equity", calculator.getEquity(ALICE, 0, 0));
      console2.log("free collateral", calculator.getFreeCollateral(ALICE, 0, 0));
    }
  }
}
