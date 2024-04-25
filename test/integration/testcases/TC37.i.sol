// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC37 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData = new bytes[](0);

  function testCorrectness_TC37() external {
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
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 50 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
      depositCollateral(ALICE, 1, wbtc, 1 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice buy long BTC 110,000 USD at 20,000 USD
    //     Alice buy short BTC 100,000 USD at 20,000 USD
    {
      // updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      // buy
      marketSell(
        ALICE,
        1,
        wbtcMarketIndex,
        110_000 * 1e30,
        address(wbtc),
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );
      marketBuy(ALICE, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // T2: Alice buy the position for 24 hours, and BTC dump 20,100
    vm.warp(block.timestamp + (24 * HOURS));
    {
      updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125.85 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_100 * 1e8, 0);
      tickPrices[1] = 99089; // WBTC tick price $20,100
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48353; // JPY tick price $125.85

      uint256 traderBalanceBefore = vaultStorage.traderBalances(ALICE, address(wbtc));
      uint256 protocolFeesBefore = vaultStorage.protocolFees(address(wbtc));
      uint256 devFeesBefore = vaultStorage.devFees(address(wbtc));
      uint256 hlpLiquidityBefore = vaultStorage.hlpLiquidity(address(wbtc));

      // shhh compiler
      traderBalanceBefore;

      liquidate(getSubAccount(ALICE, 0), tickPrices, publishTimeDiff, block.timestamp);

      /*
       * |        |     loss     |   trading   |        borrowing     |       funding    | liquidation |     Total   | unit |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P1 |      -500.00 |         100 |   1466.7524962948546 | -115.19999999712 |           5 |             |  USD |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total |      -500.00 |         100 |   1466.7524962948546 | -115.19999999712 |           5 |             |  USD |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total |  -0.02487562 |  0.00497512 |           0.07297276 |      -0.00573134 |  0.00024875 |  0.04758967 |  BTC |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    Dev |              |  0.00049751 |           0.00729727 |                  |             |  0.00779478 |  BTC |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    HLP |  -0.02487562 |             |           0.06202685 |      -0.00573134 |             |  0.03141989 |  BTC |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  P-fee |              |  0.00447761 |                      |                  |             |  0.00447761 |  BTC |
       * |--------|--------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    liq |              |             |                      |                  |  0.00024875 |  0.00024875 |  BTC |
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 4173075);
      assertVaultsFees(address(wbtc), protocolFeesBefore + (0.00447761 * 1e8), devFeesBefore + (0.00779478 * 1e8), 0);
      assertHLPLiquidity(address(wbtc), hlpLiquidityBefore + (0.03141989 * 1e8));
      assertSubAccountTokenBalance(BOT, address(wbtc), true, (0.00024875 * 1e8));
    }
  }
}
