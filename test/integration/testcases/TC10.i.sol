// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC10 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData = new bytes[](0);

  function testCorrectness_TC10() external {
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
    // T1: Alice deposits 20,000(USD) BTC as a collateral
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
      bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
      marketBuy(ALICE, 0, wbtcMarketIndex, 10_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
      marketBuy(ALICE, 0, appleMarketIndex, 10_000 * 1e30, address(usdt), tickPrices, publishTimeDiff, block.timestamp);
    }

    // T2: Alice has 2 positions at Profit and 1 positions at Loss
    vm.warp(block.timestamp + (1 * HOURS));
    {
      updatePriceData = new bytes[](4);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 127 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_000 * 1e8, 0);
      // updatePriceData[3] = _createPriceFeedUpdateData(appleAssetId, 155 * 1e5, 0);
      tickPrices[1] = 100438; // WBTC tick price $23,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[5] = 50436; // APPL tick price $152
      tickPrices[6] = 48444; // JPY tick price $127
    }

    {
      // T3: Market close
      oracleMiddleWare.setMarketStatus(appleAssetId, uint8(1));
    }

    {
      // T4: Liquidation on Alice's account happened
      uint256 traderBalanceBefore = vaultStorage.traderBalances(ALICE, address(wbtc));
      uint256 protocolFeesBefore = vaultStorage.protocolFees(address(wbtc));
      uint256 devFeesBefore = vaultStorage.devFees(address(wbtc));
      uint256 plpLiquidityBefore = vaultStorage.plpLiquidity(address(wbtc));

      liquidate(getSubAccount(ALICE, 0), tickPrices, publishTimeDiff, block.timestamp);
      /*
       * |        |                 loss                 |   trading   |        borrowing     |       funding    | liquidation |     Total   | unit |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P1 | -1574.803149606299212598425208364222 |          30 |   3.8149230299594427 |   47.99999999988 |           5 |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P2 |                                    0 |          10 |   1.2716410099864806 |   0.479999999988 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |     P3 |   197.368421052631578947368421052631 |           5 |   63.582050499324057 |   0.479999999988 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total | -1377.434728553667633651056787311591 |          45 |  68.6686145392699803 |  48.959999999856 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  Total |                           0.05988846 |  0.00195652 |           0.00298559 |       0.00212869 |  0.00021739 |  0.06717665 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    Dev |                                      |  0.00029347 |           0.00044783 |                  |             |   0.0007413 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    PLP |                           0.05988846 |             |           0.00253776 |                  |             |  0.06242622 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |  P-fee |                                      |  0.00166305 |                      |                  |             |  0.00166305 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|------------------|-------------|-------------|------|
       * |    liq |                                      |             |                      |                  |  0.00021739 |  0.00021739 |  BTC |
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 3286807);
      assertVaultsFees(address(wbtc), protocolFeesBefore + (0.00166305 * 1e8), devFeesBefore + (0.0007413 * 1e8), 0);
      assertPLPLiquidity(address(wbtc), plpLiquidityBefore + (0.06242622 * 1e8));
      assertSubAccountTokenBalance(BOT, address(wbtc), true, (0.00021739 * 1e8));

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
