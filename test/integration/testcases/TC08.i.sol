// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC08 is BaseIntTest_WithActions {
  function testCorrectness_TC08() external {
    bytes[] memory priceData = new bytes[](0);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);

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
    // T1: Alice deposits 1000(USD) BTC as a collateral
    {
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T2: Alice buy long JPYUSD 100,000 USD at 0.008 USD, sell short BTCUSD 1000 USD at priced 23,000
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 23_000 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      // buy
      bytes32 _positionId = getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(usdt), priceData);
      marketSell(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(usdt), priceData);
    }

    // T3: Alice opened the position for 3 hours, BTC pumped hard to 23,100 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (3 * HOURS));
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 23_100 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);
    }

    // T4: Alice cannot withdraw
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      withdrawCollateral(ALICE, 0, wbtc, 0.01 * 1e8, priceData);
    }

    // T4: Alice cannot close position
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      vm.expectRevert(abi.encodeWithSignature("ITradeService_SubAccountEquityIsUnderMMR()"));
      marketBuy(ALICE, 0, wbtcMarketIndex, 50_000 * 1e30, address(usdt), priceData);
    }

    // T5: Alice deposit collateral 100 USD (MMR < Equity < IMR) will not Lq
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      depositCollateral(ALICE, 0, wbtc, 0.005 * 1e8);
    }

    // T6: Alice deposit collateral 10000 USD (Equity > IMR) will not Lq
    vm.warp(block.timestamp + (1 * SECONDS));
    {
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    // T7: JPYUSD dumped priced to 0.007905138339920948 (Equity < IMR))
    vm.warp(block.timestamp + (1 * HOURS));
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 126.5 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 23_100 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      liquidate(getSubAccount(ALICE, 0), priceData);
      /*
       * |        loss        |   trading   |       borrowing     |       funding     | liquidation | unit |
       * |--------------------|-------------|---------------------|-------------------|-------------|------|
       * | 1185.7707509881423 |          30 |   15.19785330016022 | 192.0533333328532 |           5 |  USD |
       * |         0.05133206 |  0.00129870 |          0.00065791 |        0.00831399 |  0.00021645 |  BTC |
       * |--------------------|-------------|---------------------|-------------------|-------------|------|
       * |  217.3913043478261 |          50 |  126.64167400852115 |  48.0133333328532 |           5 |  USD |
       * |         0.00941087 |  0.00216450 |          0.00548232 |        0.00207849 |  0.00021645 |  BTC |
       *
       * total fee pay: 0.00129870 + 0.00065791 + 0.00831399 + 0.00216450 + 0.00548232 + 0.00207849 +  0.00021645 = 0.02021236
       * total loss pay: (1185.7707509881423 + 217.3913043478261) / 23100 = 0.06074294
       * trader balance = 0.10152175 - 0.08095530 = 0.02056645
       * dev fee = 0.00052173 + (0.00129870 * 15%) + (0.00065791 * 15%) + (0.00216450 * 15%) + (0.00548232 * 15%) = 0.00052173 + 0.00019480 + 0.00009868 + 0.00032467 + 0.00082234 = 0.00196222
       * plp liquidity = 9.97 + (0.06074294 + (0.00065791 - 0.00009868) + (0.00548232 - 0.00082234)) = 10.03596215
       * protocol fee = 0.03295652 + (0.00129870 - 0.00019480) + (0.00216450 - 0.00032467) = 0.03590025
       * liquidation fee = 0.00021645
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 0.02056645 * 1e8);
      assertVaultsFees(address(wbtc), 0.03590025 * 1e8, 0.00196222 * 1e8, 0.01039248 * 1e8);
      assertPLPLiquidity(address(wbtc), 10.03596215 * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00021645 * 1e8);
      assertNumberOfPosition(ALICE, 0);
      assertPositionInfoOf(ALICE, jpyMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(jpyMarketIndex, 0, 0);
      assertPositionInfoOf(ALICE, wbtcMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(wbtcMarketIndex, 0, 0);
    }
  }
}
