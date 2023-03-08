// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/BaseIntTest_WithActions.i.sol";

import { console2 } from "forge-std/console2.sol";

contract TC06 is BaseIntTest_WithActions {
  // T3: ETHUSD priced at 1,550 USD and the position has been opened for 6 hours (Equity < IMR)
  // T4: Alice withdraw collateral
  // T5: Alice partial close SHORT position 100 USD ETHUSD position and choose to settle with ETH  (Equity < IMR)
  // T6: Alice selll short ETHUSD 1000 USD and increase leverage
  // T7: Alice try to sell limit order ETHUSD 20 USD, but transaction is reversed
  // T8: Alice deposit collateral then IMR back to healthy
  // T9: Alice buy ETHUSD 20 USD position limit order at ETH price is 1535.4451231231 USD and decrease leverage
  // T10: Dump ETH priced to 1500 USD (Equity < IMR)
  // T11: Alice fully close SHORT ETHUSD position (Equity > IMR)
  // T12: Alice can withdraw collateral

  function setUp() public {}

  function testIntegration_WhenTraderInteractWithCrossMargin() external {
    /**
     * T0: Initialized state
     */
    vm.warp(block.timestamp + 1);
    uint8 SUB_ACCOUNT_ID = 1;
    address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);

    // Mint tokens to Alice
    {
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 100_000 * 1e6);
      // Mint DAI token to ALICE
      dai.mint(ALICE, 100_000 * 1e18);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.5 * 1e8);

      assertEq(usdc.balanceOf(ALICE), 100_000 * 1e6, "USDC Balance Of");
      assertEq(dai.balanceOf(ALICE), 100_000 * 1e18, "DAI Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.5 * 1e8, "WBTC Balance Of");
    }

    /**
     * T1: Alice deposits 100,000(USD) DAI, 100,000(USD) USDC and 10,000(USD) WBTC as collaterals
     */
    vm.warp(block.timestamp + 1);
    {
      // Before Alice start depositing, VaultStorage must has 0 amount of all collateral tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 0);
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(dai)), 0);
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0);
      assertEq(usdc.balanceOf(address(vaultStorage)), 0);
      assertEq(dai.balanceOf(address(vaultStorage)), 0);
      assertEq(wbtc.balanceOf(address(vaultStorage)), 0);

      // Alice deposits 100,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 100_000 * 1e6);

      // Alice deposits 100,000(USD) of DAI
      depositCollateral(ALICE, SUB_ACCOUNT_ID, dai, 100_000 * 1e18);

      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.5 * 1e8);

      // After Alice deposited all collaterals, VaultStorage must contain tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 100_000 * 1e6);
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(dai)), 100_000 * 1e18);
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.5 * 1e8);
      assertEq(usdc.balanceOf(address(vaultStorage)), 100_000 * 1e6);
      assertEq(dai.balanceOf(address(vaultStorage)), 100_000 * 1e18);
      assertEq(wbtc.balanceOf(address(vaultStorage)), 0.5 * 1e8);
      // After Alice deposited all collaterals, Alice must have no token left
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
      assertEq(dai.balanceOf(ALICE), 0, "DAI Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");
    }

    /**
     * T2: Alice open short ETHUSD at 2000.981234381823 USD, priced at 1500 USD
     */
    vm.warp(block.timestamp + 1);
    {
      uint256 sellSizeE30 = 2000.981234381823 * 1e30;
      address tpToken = address(glp);
      bytes[] memory priceData = new bytes[](0);

      sell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, tpToken, priceData);
    }
  }
}
