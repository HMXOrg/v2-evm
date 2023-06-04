// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract TC29 is BaseIntTest_WithActions {
  function testIntegration_WhenSubAccountHasBadDebt() external {
    /**
     * T0: Initialized state
     */
    vm.warp(block.timestamp + 1);
    uint8 SUB_ACCOUNT_ID = 1;
    address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);
    // Make LP contains some liquidity
    {
      vm.deal(BOB, 1 ether); //deal with out of gas
      wbtc.mint(BOB, 100 * 1e8);
      addLiquidity(BOB, wbtc, 100 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    }

    // Mint tokens to Alice
    {
      // Mint USDT token to ALICE
      usdt.mint(ALICE, 12_000 * 1e6);
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 9_000 * 1e6);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.5 * 1e8);

      assertEq(usdt.balanceOf(ALICE), 12_000 * 1e6, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 9_000 * 1e6, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.5 * 1e8, "WBTC Balance Of");
    }

    /**
     * T1: Alice has 2 loss positions on Sub-account 1
     */
    vm.warp(block.timestamp + 1);
    {
      // Before Alice start depositing, VaultStorage must has 0 amount of all collateral tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdt)), 0, "ALICE's USDT Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 0, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0, "ALICE's WBTC Balance");
      assertEq(usdt.balanceOf(address(vaultStorage)), 0, "Vault's USDT Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 0, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), 100 * 1e8, "Vault's WBTC Balance");
      // Alice deposits 12,000(USD) of USDT
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdt, 12_000 * 1e6);
      // Alice deposits 10,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.5 * 1e8);

      // After Alice deposited all collaterals, VaultStorage must contain tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdt)), 12_000 * 1e6, "ALICE's USDT Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.5 * 1e8, "ALICE's WBTC Balance");
      assertEq(usdt.balanceOf(address(vaultStorage)), 12_000 * 1e6, "Vault's USDT Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 9_000 * 1e6, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), (0.5 + 100) * 1e8, "Vault's WBTC Balance");
      // After Alice deposited all collaterals, Alice must have no token left
      assertEq(usdt.balanceOf(ALICE), 0, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");
    }

    /**
     * Alice sell short ETHUSD limit order at 200,000 USD (ETH price at 1500 USD)
     */

    // Assert on Global Pnl before trading occurred
    {
      // Global PNL from all markets must start with Zero since no opening trade positions yet
      assertEq(calculator.getGlobalPNLE30(), 0);
      // Unrealized Pnl on ALICE with SUB_ACCOUNT ID 1 must be Zero
      (int256 AliceUnrealizedPnl, ) = calculator.getUnrealizedPnlAndFee(SUB_ACCOUNT, 0, 0);
      assertEq(AliceUnrealizedPnl, 0);
    }

    vm.warp(block.timestamp + 1);
    {
      uint256 sellSizeE30 = 2_300_000 * 1e30;
      address tpToken = address(wbtc);

      // ALICE opens SHORT position on with WETH Market Price = 1500 USD
      vm.deal(ALICE, executionOrderFee);
      marketSell(
        ALICE,
        SUB_ACCOUNT_ID,
        wethMarketIndex,
        sellSizeE30,
        tpToken,
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );

      // Alice's Equity must be upper IMR level
      // Equity = 27_194.999999966614, IMR = 10_000
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR"
      );
    }

    // Assert on Global Pnl after trading occurred
    {
      // Global PNL from all markets must start with Zero since no opening trade positions yet
      // Note that 768955 is precision loss it mean global PNL = 768955 / 1e30 that approximate to Zero
      assertEq(calculator.getGlobalPNLE30(), -768955, "getGlobalPNLE30");
      // Unrealized Pnl on ALICE with SUB_ACCOUNT ID 1 must be Zero
      (int256 AliceUnrealizedPnl, ) = calculator.getUnrealizedPnlAndFee(SUB_ACCOUNT, 0, 0);
      assertEq(AliceUnrealizedPnl, 0, "UnrealizedPnlAndFee");
    }

    /**
     * T2: Alice's sub account 1 equity goes below MMR
     */
    vm.warp(block.timestamp + 15);
    {
      //  Set Price for BTCUSD expected make Alice's Equity < MMR
      // bytes32[] memory _assetIds = new bytes32[](1);
      // int64[] memory _prices = new int64[](1);
      // uint64[] memory _confs = new uint64[](1);
      // _assetIds[0] = wethAssetId;
      // _prices[0] = 2000 * 1e8;
      // _confs[0] = 2;
      tickPrices[0] = 76012; // ETH tick price $2,000
      setPrices(tickPrices, publishTimeDiff);

      // Alice's Equity must be lower MMR level
      assertTrue(
        calculator.getEquity(SUB_ACCOUNT, 0, 0) < int(calculator.getMMR(SUB_ACCOUNT)),
        "ALICE's Equity < MMR?"
      );

      // Assert on Global Pnl after set ETH price from 1,500 to 2,000
      {
        // Global PNL must be equal to Alice's unrealized Pnl
        (int256 AliceUnrealizedPnl, ) = calculator.getUnrealizedPnlAndFee(SUB_ACCOUNT, 0, 0);
        assertApproxEqRel(calculator.getGlobalPNLE30(), -AliceUnrealizedPnl, MAX_DIFF, "getGlobalPNLE30");
      }
    }

    /**
     * T3: Liquidation on Alice's account happened
     */
    vm.warp(block.timestamp + 15);
    {
      // ALICE's position before liquidate must contain 1 position
      IPerpStorage.Position[] memory traderPositionBefore = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionBefore.length, 1);

      bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
      bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiff);

      botHandler.liquidate(
        SUB_ACCOUNT,
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );

      // ALICE's position before liquidate must contain 0 position
      IPerpStorage.Position[] memory traderPositionAfter = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionAfter.length, 0);

      // Assert on Global Pnl after Liquidate Alice's position
      {
        // Global PNL must be equal to Alice's unrealized Pnl
        (int256 AliceUnrealizedPnl, ) = calculator.getUnrealizedPnlAndFee(SUB_ACCOUNT, 0, 0);
        assertApproxEqRel(calculator.getGlobalPNLE30(), -AliceUnrealizedPnl, MAX_DIFF, "getGlobalPNLE30");
      }
    }

    /**
     * T4: Alice's account equity = 0, MMR = 0 USD
     */
    vm.warp(block.timestamp + 1);
    {
      assertEq(calculator.getEquity(SUB_ACCOUNT, 0, 0), 0);
      assertEq(calculator.getIMR(SUB_ACCOUNT), 0);
      assertEq(calculator.getMMR(SUB_ACCOUNT), 0);
    }

    /**
     * T5: Alice's Deposit more collateral
     */
    vm.warp(block.timestamp + 1);
    {
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 9_000 * 1e6);
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);

      // After Alice deposited USDC
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), (9_000 + 9_000) * 1e6, "Vault's USDC Balance");
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
    }

    /**
     * T6: Alice buy Long ETH 3000 USD
     */
    vm.warp(block.timestamp + 1);
    {
      uint256 buySizeE30 = 3_000 * 1e30;
      address tpToken = address(wbtc); // @note settle with WBTC that be treated as GLP token
      vm.deal(ALICE, 1 ether);

      marketBuy(
        ALICE,
        SUB_ACCOUNT_ID,
        wethMarketIndex,
        buySizeE30,
        tpToken,
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );

      // ALICE's position after open new position
      IPerpStorage.Position[] memory traderPositionAfter = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionAfter.length, 1);
    }
  }
}
