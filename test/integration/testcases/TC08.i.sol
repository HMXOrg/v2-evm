// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC08 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC08() external {
    vm.warp(1698207980);
    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      usdt.mint(ALICE, 100_000 * 1e6);
      wbtc.mint(ALICE, 0.5 * 1e8);

      wbtc.mint(BOB, 10 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice deposits 10,000(USD) BTC as a collateral
    {
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T2: Alice buy long JPYUSD 100,000 USD at 0.008 USD, sell short BTCUSD 1000 USD at priced 23,000
    {
      updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_000 * 1e8, 0);
      tickPrices[1] = 100438; // WBTC tick price $23,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      // buy
      getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);

      assertEq(perpStorage.getEpochVolume(true, jpyMarketIndex), 100_000 * 1e30);

      marketSell(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);

      assertEq(perpStorage.getEpochVolume(false, wbtcMarketIndex), 50_000 * 1e30);
    }

    // T3: Alice opened the position for 3 hours, BTC pumped hard to 23,100 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (3 * HOURS));

    assertEq(perpStorage.getEpochVolume(true, jpyMarketIndex), 0);
    assertEq(perpStorage.getEpochVolume(false, wbtcMarketIndex), 0);

    {
      updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_100 * 1e8, 0);
      tickPrices[1] = 100481; // WBTC tick price $23,100
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125
    }

    // T4: Alice cannot withdraw
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      // vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      withdrawCollateral(ALICE, 0, wbtc, 0.01 * 1e8, tickPrices, publishTimeDiff, block.timestamp, executionOrderFee);
    }

    // T4: Alice cannot close position
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      marketBuy(
        ALICE,
        0,
        wbtcMarketIndex,
        50_000 * 1e30,
        address(usdt),
        tickPrices,
        publishTimeDiff,
        block.timestamp,
        "ITradeService_SubAccountEquityIsUnderMMR()"
      );
    }

    // T5: Alice deposit collateral 100 USD (MMR < Equity < IMR) will not Lq
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      depositCollateral(ALICE, 0, wbtc, 0.005 * 1e8);
    }

    {
      // vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      withdrawCollateral(ALICE, 0, wbtc, 0.01 * 1e8, tickPrices, publishTimeDiff, block.timestamp, executionOrderFee);
    }

    {
      liquidate(
        getSubAccount(ALICE, 0),
        tickPrices,
        publishTimeDiff,
        block.timestamp,
        "ILiquidationService_AccountHealthy()"
      );
    }

    // T6: Alice deposit collateral 10000 USD (Equity > IMR) will not Lq
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    {
      liquidate(
        getSubAccount(ALICE, 0),
        tickPrices,
        publishTimeDiff,
        block.timestamp,
        "ILiquidationService_AccountHealthy()"
      );
    }
  }
}
