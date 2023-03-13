// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { console2 } from "forge-std/console2.sol";

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
      bytes[] memory priceData = new bytes[](0);
      vm.deal(BOB, 1 ether); //deal with out of gas
      wbtc.mint(BOB, 10 * 1e8);
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData);
    }

    // Mint tokens to Alice
    {
      // Mint USDT token to ALICE
      usdt.mint(ALICE, 12_000 * 1e6);
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 9_000 * 1e6);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.05 * 1e8);

      assertEq(usdt.balanceOf(ALICE), 12_000 * 1e6, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 9_000 * 1e6, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.05 * 1e8, "WBTC Balance Of");
    }

    /**
     * T1: Alice has 2 position Loss on Sub-account 1
     */

    vm.warp(block.timestamp + 1);
    {
      // Before Alice start depositing, VaultStorage must has 0 amount of all collateral tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdt)), 0, "ALICE's USDT Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 0, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0, "ALICE's WBTC Balance");
      assertEq(usdt.balanceOf(address(vaultStorage)), 0, "Vault's USDT Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 0, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), 10 * 1e8, "Vault's WBTC Balance");

      // Alice deposits 12,000(USD) of USDT
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdt, 12_000 * 1e6);

      // Alice deposits 10,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);

      // Alice deposits 1,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.05 * 1e8);

      // After Alice deposited all collaterals, VaultStorage must contain tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdt)), 12_000 * 1e6, "ALICE's USDT Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.05 * 1e8, "ALICE's WBTC Balance");
      assertEq(usdt.balanceOf(address(vaultStorage)), 12_000 * 1e6, "Vault's USDT Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 9_000 * 1e6, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), (0.05 + 10) * 1e8, "Vault's WBTC Balance");
      // After Alice deposited all collaterals, Alice must have no token left
      assertEq(usdt.balanceOf(ALICE), 0, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");
    }

    /**
     * Alice sell short ETHUSD limit order at 450,000 USD (ETH price at 1500 USD)
     */

    vm.warp(block.timestamp + 1);
    {
      uint256 sellSizeE30 = 200_000 * 1e30;
      address tpToken = address(wbtc);
      bytes[] memory priceData = new bytes[](0);

      // ALICE opens SHORT position with WETH Market Price = 1500 USD
      marketSell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, tpToken, priceData);

      // Alice's Equity must be upper IMR level
      // Equity = 1051.8309859154929, IMR = 3200
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR"
      );
    }

    /**
     * T2: Alice's sub account 1 equity goes below MMR
     */

    vm.warp(block.timestamp + 1);
    {
      //  Set Price for ETHUSD to 1,550 USD
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = wethAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = daiAssetId;
      _assetIds[3] = wbtcAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 1_650;
      _prices[1] = 1;
      _prices[2] = 1;
      _prices[3] = 20_000;

      setPrices(_assetIds, _prices);

      // Alice's Equity must be lower MMR level
      assertTrue(
        calculator.getEquity(SUB_ACCOUNT, 0, 0) < int(calculator.getMMR(SUB_ACCOUNT)),
        "ALICE's Equity < MMR?"
      );
    }

    /**
     * T3: Liquidation on Alice's account happened
     */
    vm.warp(block.timestamp + 1);
    {
      // ALICE's position before liquidate must contain 1 position
      IPerpStorage.Position[] memory traderPositionBefore = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionBefore.length, 1);

      bytes[] memory prices = new bytes[](0);
      botHandler.liquidate(SUB_ACCOUNT, prices);

      // ALICE's position before liquidate must contain 0 position
      IPerpStorage.Position[] memory traderPositionAfter = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionAfter.length, 0);
    }

    /**
     * T4: Alice's account equity = 0, MMR = 0 USD
     */
    vm.warp(block.timestamp + 1);
    {
      // @todo - already liquidated but bad debt still not occurred
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
      bytes[] memory priceData = new bytes[](0);

      marketBuy(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, buySizeE30, tpToken, priceData);

      // ALICE's position after open new position
      IPerpStorage.Position[] memory traderPositionAfter = perpStorage.getPositionBySubAccount(SUB_ACCOUNT);
      assertEq(traderPositionAfter.length, 1);
    }
  }
}
