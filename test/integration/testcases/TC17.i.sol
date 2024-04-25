// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC17 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData = new bytes[](0);

  function testCorrectness_TC17() external {
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
    // T1: Alice deposits 1000(USD) BTC as a collateral
    {
      depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    //T1: Alice buy 3 positions
    {
      updatePriceData = new bytes[](4);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_000 * 1e8, 0);
      // updatePriceData[3] = _createPriceFeedUpdateData(appleAssetId, 152 * 1e5, 0);
      tickPrices[1] = 100438; // WBTC tick price $23,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[5] = 50241; // APPL tick price $152
      tickPrices[6] = 48285; // JPY tick price $125

      // buy
      getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
      marketBuy(ALICE, 0, wbtcMarketIndex, 10_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
      marketBuy(ALICE, 0, appleMarketIndex, 10_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
    }

    // T2: Alice has 2 positions at Profit and 1 positions at Loss
    vm.warp(block.timestamp + (1 * HOURS));
    {
      updatePriceData = new bytes[](4);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 130 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_500 * 1e8, 0);
      // updatePriceData[3] = _createPriceFeedUpdateData(appleAssetId, 155 * 1e5, 0);
      tickPrices[1] = 100653; // WBTC tick price $23,500
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[5] = 50436; // APPL tick price $155
      tickPrices[6] = 48677; // JPY tick price $130
    }

    {
      // T3: Liquidation on Alice's account happened
      uint256 traderBalanceBefore = vaultStorage.traderBalances(ALICE, address(wbtc));
      uint256 protocolFeesBefore = vaultStorage.protocolFees(address(wbtc));
      uint256 devFeesBefore = vaultStorage.devFees(address(wbtc));
      uint256 hlpLiquidityBefore = vaultStorage.hlpLiquidity(address(wbtc));

      liquidate(getSubAccount(ALICE, 0), tickPrices, publishTimeDiff, block.timestamp);
      /*
       * |        |                 loss                 |   trading   |        borrowing     |       funding    | liquidation |     Total   | unit |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P1 | -3846.153846153846153846153849518669 |          30 |   3.7337544548539227 |   47.99999999988 |           5 |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P2 |   217.391304347826086956521739130434 |          10 |   1.2445848182846403 |   0.479999999988 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P3 |   197.368421052631578947368421052631 |           5 |  62.2292409142320555 |   0.479999999988 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total | -3431.394120753388487942263689335604 |          45 |  67.2075801873706185 |  48.959999999856 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total |                           0.14601677 |  0.00191489 |           0.00285989 |       0.00208340 |  0.00021276 |  0.15308771 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    Dev |                                      |  0.00019148 |           0.00028598 |                  |             |  0.00047746 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    HLP |                           0.14601677 |             |           0.00243091 |                  |             |  0.14844768 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  P-fee |                                      |  0.00172341 |                      |                  |             |  0.00172341 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    liq |                                      |             |                      |                  |  0.00021276 |  0.00021276 |  BTC |
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), false, 0);
      assertVaultsFees(address(wbtc), protocolFeesBefore + (0.00172341 * 1e8), devFeesBefore + (0.00047746 * 1e8), 0);
      assertHLPLiquidity(address(wbtc), hlpLiquidityBefore + traderBalanceBefore - (0.15308771 - 0.14844768) * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, (0.00021276 * 1e8));

      assertNumberOfPosition(ALICE, 0);
      assertPositionInfoOf(ALICE, jpyMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(jpyMarketIndex, 0, 0);
      assertPositionInfoOf(ALICE, wbtcMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(wbtcMarketIndex, 0, 0);
      assertPositionInfoOf(ALICE, appleMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(appleMarketIndex, 0, 0);
    }
  }
}
