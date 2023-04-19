// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC08 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC08() external {
    bytes[] memory priceData = new bytes[](0);
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
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, true);
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
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_000 * 1e8, 0);

      // buy
      bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(usdt), updatePriceData);
      marketSell(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(usdt), updatePriceData);
    }

    // T3: Alice opened the position for 3 hours, BTC pumped hard to 23,100 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (3 * HOURS));
    {
      updatePriceData = new bytes[](3);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_100 * 1e8, 0);
    }

    // T4: Alice cannot withdraw
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      // vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      withdrawCollateral(ALICE, 0, wbtc, 0.01 * 1e8, updatePriceData, executionOrderFee);
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
        updatePriceData,
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
      withdrawCollateral(ALICE, 0, wbtc, 0.01 * 1e8, updatePriceData, executionOrderFee);
    }

    {
      vm.expectRevert(abi.encodeWithSignature("ILiquidationService_AccountHealthy()"));
      liquidate(getSubAccount(ALICE, 0), updatePriceData);
    }

    // T6: Alice deposit collateral 10000 USD (Equity > IMR) will not Lq
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    {
      vm.expectRevert(abi.encodeWithSignature("ILiquidationService_AccountHealthy()"));
      liquidate(getSubAccount(ALICE, 0), updatePriceData);
    }

    // T7: JPYUSD dumped priced to 0.007905138339920948 (Equity < IMR))
    vm.warp(block.timestamp + (1 * HOURS));
    {
      updatePriceData = new bytes[](3);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 126.5 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 23_100 * 1e8, 0);

      liquidate(getSubAccount(ALICE, 0), updatePriceData);
      /*
       * |        |                 loss                 |   trading   |        borrowing     |       funding     | liquidation |     Total   | unit |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |     P1 | -1185.770750988142292490118592783943 |          30 |  15.1978533001602201 | 192.0533333328532 |           5 |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |     P2 |  -217.391304347826086956521739130434 |          50 | 126.6487775013351735 |  48.0133333328532 |             |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |  Total | -1403.162055335968379446640331914377 |          80 | 141.8466308014953936 | 240.0666666657062 |           5 |             |  USD |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |  Total |                           0.06074294 |  0.00346320 |           0.00614054 |        0.01039249 |  0.00021645 |  0.08095562 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |    Dev |                                      |  0.00051948 |           0.00092108 |                   |             |  0.00144056 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |    PLP |                           0.06074294 |             |           0.00521946 |                   |             |   0.0659624 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |  P-fee |                                      |  0.00294372 |                      |                   |             |  0.00294372 |  BTC |
       * |--------|--------------------------------------|-------------|----------------------|-------------------|-------------|-------------|------|
       * |    liq |                                      |             |                      |                   |  0.00021645 |  0.00021645 |  BTC |
       *
       * trader balance = 0.10152175 - 0.08095562 = 0.02056613
       * dev fee = 0.00052173 + 0.00144056 = 0.00196229
       * plp liquidity = 9.97000000 + 0.0659624 = 10.0359624
       * protocol fee = 0.03295652 + 0.00294372 = 0.03590024
       * liquidation fee = 0.00021645
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 0.02056613 * 1e8);
      assertVaultsFees(address(wbtc), 0.03590024 * 1e8, 0.00196229 * 1e8, 0.01039249 * 1e8);
      assertPLPLiquidity(address(wbtc), 10.0359624 * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00021645 * 1e8);
      assertNumberOfPosition(ALICE, 0);
      assertPositionInfoOf(ALICE, jpyMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(jpyMarketIndex, 0, 0);
      assertPositionInfoOf(ALICE, wbtcMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(wbtcMarketIndex, 0, 0);
    }
  }
}
