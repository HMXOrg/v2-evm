// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

import { console2 } from "forge-std/console2.sol";

contract TC00 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC00() external {
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
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 50 * 1e8, executionOrderFee, priceData, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
      depositCollateral(ALICE, 1, wbtc, 1 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
    {
      updatePriceData = new bytes[](3);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);

      // buy
      // bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);

      marketSell(ALICE, 1, wbtcMarketIndex, 110_000 * 1e30, address(wbtc), updatePriceData);
      marketBuy(ALICE, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), updatePriceData);
    }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.007945967421533571712355979340 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (24 * HOURS));
    {
      updatePriceData = new bytes[](3);
      updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125.85 * 1e3, 0);
      updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_100 * 1e8, 0);

      liquidate(getSubAccount(ALICE, 0), updatePriceData);
      /*
       *
       * |       loss        |   trading   |      borrowing     |      funding     | liquidation | unit |
       * |-------------------|-------------|--------------------|------------------|-------------|------|
       * |            500.00 |         100 | 1466.7524962948546 | -115.19999999712 |           5 |  USD |
       * |        0.02487562 |  0.00497512 |         0.07297276 |      -0.00573134 |  0.00024875 |  BTC |
       *
       * total pay: 0.00497512 + 0.07297276 + 0.00024875 = 0.07819663
       * total receive: 0.02487562 + 0.00573134 = 0.03060696
       * trader balance = 0.095 + 0.03060696 - 0.07819663 = 0.04741033
       * dev fee = (0.00497512 * 15%) + (0.07297276 * 15%) = 0.00074626 + 0.01094591 = 0.01169217 | 0.001575 + 0.01169217 = 0.01326717
       * plp liquidity = 0.07297276 - 0.01094591 = 0.06202685 | 49.85 + 0.06202685 - 0.02487562 - 0.00573134 = 49.88141989
       * protocol fee = 0.00497512 - 0.00074626 = 0.00422886 | 0.158925 + 0.00422886 = 0.16315386
       * liquidation fee = 0.00025
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 0.04741033 * 1e8);
      assertVaultsFees(address(wbtc), 0.16315386 * 1e8, 0.01326717 * 1e8, 0 * 1e8);
      assertPLPLiquidity(address(wbtc), 49.88141989 * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00024875 * 1e8);
      assertNumberOfPosition(ALICE, 0);
    }
  }

  function testCorrectness_notRevertWhenTpTokenNotEnough() external {
    // prepare token for wallet

    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // warp to block timestamp 1000
    vm.warp(1000);

    // T1: BOB provide liquidity as WBTC 1 token
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0), true);

    skip(60);

    // T2: ALICE deposit BTC 200 USD at price 20,000
    // 200 / 20000 = 0.01 BTC
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    depositCollateral(ALICE, 0, wbtc, 0.01 * 1e8);

    skip(60);

    // T3: ALICE market buy weth with 300 USD at price 1,500 USD
    //     Then Alice should has Long Position in WETH market
    marketBuy(ALICE, 0, wethMarketIndex, 300 * 1e30, address(0), new bytes[](0));

    skip(60);

    // T4: Alice partial close Long position at WETH market for 150 USD
    //     WETH price 1,575 USD, then Alice should take profit ~5%
    // Expected: this transaction must not revert although no USDT on Vault storage.
    //           TP token will be switched to WBTC instead
    updatePriceData = new bytes[](1);
    updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1_575 * 1e8, 0);
    marketSell(ALICE, 0, wethMarketIndex, 50 * 1e30, address(usdt), updatePriceData);
    marketSell(ALICE, 0, wethMarketIndex, 50 * 1e30, address(usdc), updatePriceData);
    marketSell(ALICE, 0, wethMarketIndex, 50 * 1e30, address(dai), updatePriceData);
  }
}
