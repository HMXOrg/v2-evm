// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

import { console2 } from "forge-std/console2.sol";

contract TC00 is BaseIntTest_WithActions {
  function testCorrectness_TC00() external {
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
      // bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);

      marketSell(ALICE, 1, wbtcMarketIndex, 110_000 * 1e30, address(wbtc), priceData);
      marketBuy(ALICE, 0, wbtcMarketIndex, 100_000 * 1e30, address(wbtc), priceData);
    }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.007945967421533571712355979340 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (24 * HOURS));
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125.85 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 20_100 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      console2.log("trader balance", vaultStorage.traderBalances(ALICE, address(wbtc)));
      console2.log("protocolFees", vaultStorage.protocolFees(address(wbtc)));
      console2.log("devFees", vaultStorage.devFees(address(wbtc)));
      console2.log("plpLiquidity", vaultStorage.plpLiquidity(address(wbtc)));

      liquidate(getSubAccount(ALICE, 0), priceData);
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
}
