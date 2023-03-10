// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

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
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, 0);
    }

    // Mint tokens to Alice
    {
      // Mint WETH token to ALICE
      weth.mint(ALICE, 8 * 1e18); // @note mint weth in value of 99_750 USD instead of 100_000 cause prevent decimal case (100_000 / 1_500 = 66.66666666666667 WETH)
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 9_000 * 1e6);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.05 * 1e8);

      assertEq(weth.balanceOf(ALICE), 8 * 1e18, "WETH Balance Of");
      assertEq(usdc.balanceOf(ALICE), 9_000 * 1e6, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.05 * 1e8, "WBTC Balance Of");
    }

    /**
     * T1: Alice deposits 12,000(USD) WETH, 9,000(USD) USDC and 1,000(USD) WBTC as collaterals
     */
    console2.log(
      "======================== T1: Alice deposits 12,000(USD) WETH, 9,000(USD) USDC and 1,000(USD) WBTC as collaterals"
    );
    vm.warp(block.timestamp + 1);
    {
      // Before Alice start depositing, VaultStorage must has 0 amount of all collateral tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(weth)), 0, "ALICE's WETH Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 0, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0, "ALICE's WBTC Balance");
      assertEq(weth.balanceOf(address(vaultStorage)), 0, "Vault's WETH Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 0, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), 10 * 1e8, "Vault's WBTC Balance");

      // Alice deposits 12,000(USD) of WETH
      depositCollateral(ALICE, SUB_ACCOUNT_ID, MockErc20(address(weth)), 8 * 1e18);

      // Alice deposits 10,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);

      // Alice deposits 1,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.05 * 1e8);

      // After Alice deposited all collaterals, VaultStorage must contain tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(weth)), 8 * 1e18, "ALICE's WETH Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 9_000 * 1e6, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.05 * 1e8, "ALICE's WBTC Balance");
      assertEq(weth.balanceOf(address(vaultStorage)), 8 * 1e18, "Vault's WETH Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 9_000 * 1e6, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), (0.05 + 10) * 1e8, "Vault's WBTC Balance");
      // After Alice deposited all collaterals, Alice must have no token left
      assertEq(weth.balanceOf(ALICE), 0, "WETH Balance Of");
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");

      console2.log("EQUITY", calculator.getEquity(SUB_ACCOUNT, 0, 0));
      console2.log("IMR", calculator.getIMR(SUB_ACCOUNT));
    }
  }
}
