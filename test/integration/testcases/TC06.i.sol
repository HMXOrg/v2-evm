// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { console2 } from "forge-std/console2.sol";

contract TC06 is BaseIntTest_WithActions {
  // T6: Alice selll short ETHUSD 1000 USD and increase leverage
  // T7: Alice try to sell limit order ETHUSD 20 USD, but transaction is reversed
  // T8: Alice deposit collateral then IMR back to healthy
  // T9: Alice buy ETHUSD 20 USD position limit order at ETH price is 1535.4451231231 USD and decrease leverage
  // T10: Dump ETH priced to 1500 USD (Equity < IMR)
  // T11: Alice fully close SHORT ETHUSD position (Equity > IMR)
  // T12: Alice can withdraw collateral

  function testIntegration_WhenTraderInteractWithCrossMargin() external {
    /**
     * T0: Initialized state
     */
    vm.warp(block.timestamp + 1);
    uint8 SUB_ACCOUNT_ID = 1;
    uint16 SIX_HOURS_TIMESTAMP = 6 * 60 * 60;
    address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);

    // Make LP contains some liquidity
    bytes[] memory priceDataT0 = new bytes[](0);
    vm.deal(BOB, 1 ether); //deal with out of gas
    usdt.mint(BOB, 1_000_000 * 1e6);
    addLiquidity(BOB, usdt, 1_000_000 * 1e6, executionOrderFee, priceDataT0, 0);

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
    console2.log("====================================================== T1");
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
      console2.log("ALICE FREE COL", calculator.getEquity(SUB_ACCOUNT, 0, 0));
      console2.log("ALICE FREE COL", calculator.getFreeCollateral(SUB_ACCOUNT, 0, 0));
    }

    /**
     * T2: Alice open short ETHUSD at 2000.981234381823 USD, priced at 1500 USD
     */
    console2.log("====================================================== T2");
    vm.warp(block.timestamp + 1);
    {
      // Check states Before Alice opening SHORT position

      // Calculate assert data
      // ALICE's Equity = 80_000 + 80_000 + 8_000 = 168_000
      //   | USDC collateral value = amount * price * collateralFactor = 100_000 * 1 * 0.8 = 80_000
      //   | DAI collateral value = amount * price * collateralFactor = 100_000 * 1 * 0.8 = 80_000
      //   | WBTC collateral value = amount * price * collateralFactor = 0.5 * 20_000 * 0.8 = 8_000
      // ALICE's IMR must be 0
      assertEq(calculator.getEquity(SUB_ACCOUNT, 0, 0), 168_000 * 1e30, "ALICE's Equity");
      assertEq(calculator.getIMR(SUB_ACCOUNT), 0, "ALICE's IMR");

      uint256 sellSizeE30 = 810_000.981234381823 * 1e30;
      address tpToken = address(glp);
      bytes[] memory priceDataT2 = new bytes[](0);

      // ALICE opens SHORT position with WETH Market Price = 1500 USD
      marketSell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, tpToken, priceDataT2);

      // Check states After Alice opened SHORT position
      // Alice's Equity must be upper IMR level
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR?"
      );
      console2.log("EQUITY", calculator.getEquity(SUB_ACCOUNT, 0, 0));
      console2.log("ALICE FREE COL", calculator.getFreeCollateral(SUB_ACCOUNT, 0, 0));
    }

    console2.log("====================================================== T3");
    /**
     * T3: ETHUSD priced at 1,550 USD and the position has been opened for 6 hours (Equity < IMR)
     */
    // warp block timestamp to 6 hours later
    vm.warp(block.timestamp + SIX_HOURS_TIMESTAMP);
    {
      //  Set Price for ETHUSD to 1,550 USD
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = wethAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = daiAssetId;
      _assetIds[3] = wbtcAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 1_550;
      _prices[1] = 1;
      _prices[2] = 1;
      _prices[3] = 20_000;

      setPrices(_assetIds, _prices);
      console2.log("EQUITY", calculator.getEquity(SUB_ACCOUNT, 0, 0));
      console2.log("IMR", calculator.getIMR(SUB_ACCOUNT));
      console2.log("FREE COL", calculator.getFreeCollateral(SUB_ACCOUNT, 0, 0));

      // Check states After WETH market price move from 1500 USD to 1550 USD
      // Alice's Equity must be lower IMR level
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) < calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity < ALICE's IMR?"
      );
    }

    /**
     * T4: Alice try withdrawing collateral but Alice can't withdraw
     */
    vm.warp(block.timestamp + 1);
    {
      // Alice withdraw 1(USD) of USDC
      // Expect Alice can't withdraw collateral because Equity < IMR
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      bytes[] memory priceDataT4 = new bytes[](0);
      withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 1 * 1e6, priceDataT4);
    }

    /**
     * T5: Alice partial close SHORT position 100 USD ETHUSD position and choose to settle with ETH  (Equity < IMR)
     */
    console2.log("====================================================== T5");
    {
      // ALICE partial close SHORT position with WETH Market Price = 1550 USD
      uint256 buySizeE30 = 100_000 * 1e30;
      address tpToken = address(glp);
      bytes[] memory priceDataT5 = new bytes[](0);
      // marketBuy(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, buySizeE30, tpToken, priceDataT5);
    }
  }
}
