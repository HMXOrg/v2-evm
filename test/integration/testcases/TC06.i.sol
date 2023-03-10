// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract TC06 is BaseIntTest_WithActions {
  function testIntegration_WhenTraderInteractWithCrossMargin() external {
    /**
     * T0: Initialized state
     */
    vm.warp(block.timestamp + 1);
    uint8 SUB_ACCOUNT_ID = 1;
    address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);
    address TP_TOKEN = address(wbtc); // @note settle with WBTC that be treated as GLP token

    // Make LP contains some liquidity
    {
      bytes[] memory priceData = new bytes[](0);
      vm.deal(BOB, 1 ether); //deal with out of gas
      wbtc.mint(BOB, 10 * 1e8);
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, 0);
    }

    // Mint tokens to Alice
    {
      // Mint USDT token to ALICE
      usdt.mint(ALICE, 100_000 * 1e6);
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 100_000 * 1e6);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.5 * 1e8);

      assertEq(usdt.balanceOf(ALICE), 100_000 * 1e6, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 100_000 * 1e6, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.5 * 1e8, "WBTC Balance Of");
    }

    /**
     * T1: Alice deposits 100,000(USD) USDT, 100,000(USD) USDC and 10,000(USD) WBTC as collaterals
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

      // Alice deposits 100,000(USD) of USDT
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdt, 100_000 * 1e6);

      // Alice deposits 100,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 100_000 * 1e6);

      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.5 * 1e8);

      // After Alice deposited all collaterals, VaultStorage must contain some tokens
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdt)), 100_000 * 1e6, "ALICE's USDT Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 100_000 * 1e6, "ALICE's USDC Balance");
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(wbtc)), 0.5 * 1e8, "ALICE's WBTC Balance");
      assertEq(usdt.balanceOf(address(vaultStorage)), 100_000 * 1e6, "Vault's USDT Balance");
      assertEq(usdc.balanceOf(address(vaultStorage)), 100_000 * 1e6, "Vault's USDC Balance");
      assertEq(wbtc.balanceOf(address(vaultStorage)), (0.5 + 10) * 1e8, "Vault's WBTC Balance");
      // After Alice deposited all collaterals, Alice must have no token left
      assertEq(usdt.balanceOf(ALICE), 0, "USDT Balance Of");
      assertEq(usdc.balanceOf(ALICE), 0, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0, "WBTC Balance Of");
    }

    /**
     * T2: Alice open short ETHUSD at 2000.981234381823 USD, priced at 1500 USD
     */

    vm.warp(block.timestamp + 1);
    {
      // Check states Before Alice opening SHORT position

      // Calculate assert data
      // ALICE's Equity = 100_000 + 100_000 + 8_000 = 208_000 USD
      //   | WETH collateral value = amount * price * collateralFactor = 100_000 * 1 * 1 = 100_000
      //   | USDC collateral value = amount * price * collateralFactor = 100_000 * 1 * 1 = 100_000
      //   | WBTC collateral value = amount * price * collateralFactor = 0.5 * 20_000 * 0.8 = 8_000
      // ALICE's IMR & MMR must be 0
      assertEq(calculator.getEquity(SUB_ACCOUNT, 0, 0), 208_000 * 1e30, "ALICE's Equity");
      assertEq(calculator.getIMR(SUB_ACCOUNT), 0, "ALICE's IMR");
      assertEq(calculator.getMMR(SUB_ACCOUNT), 0, "ALICE's MMR");

      uint256 sellSizeE30 = 280_000.981234381823 * 1e30;
      bytes[] memory priceData = new bytes[](0);

      // ALICE opens SHORT position with WETH Market Price = 1500 USD
      marketSell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, TP_TOKEN, priceData);

      // Check states After Alice opened SHORT position
      // Alice's Equity must be upper IMR level
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR?"
      );
    }

    /**
     * T3: ETHUSD priced at 2893 USD and the position has been opened for 6s (Equity < IMR)
     */

    vm.warp(block.timestamp + 6);
    {
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = wethAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = daiAssetId;
      _assetIds[3] = wbtcAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 2_480; // @note - if set ETH to 2893 USD, Equity will < MMR level
      _prices[1] = 1;
      _prices[2] = 1;
      _prices[3] = 20_000;
      setPrices(_assetIds, _prices);

      // Check states After WETH market price move from 1500 USD to 1550 USD
      // Alice's Equity must be lower IMR level
      // Equity = 2687.7082107743113, IMR = 2800.0098123438183
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) < calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity < ALICE's IMR?"
      );
    }

    /**
     * T4: Alice try withdrawing collateral when Equity < IMR but Alice can't withdraw (Equity < IMR)
     */

    vm.warp(block.timestamp + 1);
    {
      // Alice withdraw 1(USD) of USDC
      // Expect Alice can't withdraw collateral because Equity < IMR
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      bytes[] memory priceData = new bytes[](0);
      withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 1 * 1e6, priceData);
    }

    /**
     * T5: Alice partial close SHORT position 0.88 USD ETHUSD position and choose to settle with WBTC (Equity < IMR)
     */
    vm.warp(block.timestamp + 1);
    {
      int256 unrealizedPnlValueBefore = calculator.getUnrealizedPnl(SUB_ACCOUNT, 0, 0);

      uint256 buySizeE30 = 0.88 * 1e30;
      bytes[] memory priceData = new bytes[](0);
      marketBuy(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, buySizeE30, TP_TOKEN, priceData);

      int256 unrealizedPnlValueAfter = calculator.getUnrealizedPnl(SUB_ACCOUNT, 0, 0);

      // Expect Unrealized Pnl value will be decreased after ALICE partials close on SHORT position
      assertTrue(
        unrealizedPnlValueBefore < unrealizedPnlValueAfter,
        "ALICE unrealizedPnlValueBefore < unrealizedPnlValueAfter"
      );
      // Alice's Equity must still be lower IMR level
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) < calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity < ALICE's IMR?"
      );
    }

    /**
     * T6: Alice sell short ETHUSD 1000 USD and increase leverage
     */
    vm.warp(block.timestamp + 1);
    {
      uint256 sellSizeE30 = 1_000 * 1e30;
      bytes[] memory priceData = new bytes[](0);

      // ALICE opens SHORT position with WETH Market Price = 1500 USD
      // Expect Alice can't increase SHORT position because Equity < IMR
      vm.expectRevert(abi.encodeWithSignature("ITradeService_SubAccountEquityIsUnderIMR()"));
      marketSell(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, sellSizeE30, TP_TOKEN, priceData);
    }

    /**
     * T7: Alice try to sell limit order ETHUSD 20 USD, but transaction is reversed
     */
    {
      vm.deal(ALICE, 1 ether); //deal with out of gas
      vm.prank(ALICE);
      int256 sellSizeE30 = 20 * 1e30;
      uint256 triggerPrice = 1535.4451231231 * 1e30;

      // @todo - limitTradeHandler still not has logic for prevent trader to opening limit order when their Equity < IMR
      // Create Sell Order
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_ID,
        _marketIndex: wethMarketIndex,
        _sizeDelta: sellSizeE30,
        _triggerPrice: triggerPrice,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: false,
        _tpToken: TP_TOKEN
      });
    }

    /**
     * T8: Alice deposit collateral then IMR back to healthy
     */
    {
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 100_000 * 1e6);
      // Alice deposits 100,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 100_000 * 1e6);

      // Alice's Equity must be upper IMR level
      // Equity = 102545.80392652086, IMR = 2800.0098123438183
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR?"
      );
    }

    /**
     * T9: Alice buy ETHUSD 20 USD position limit order at ETH price is 1535.4451231231 USD and decrease leverage
     */
    {
      vm.deal(ALICE, 1 ether); //deal with out of gas
      vm.prank(ALICE);
      // Create Buy Order
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_ID,
        _marketIndex: 0,
        _sizeDelta: 20 * 1e30,
        _triggerPrice: 1535.4451231231 * 1e30,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: false,
        _tpToken: TP_TOKEN
      });
    }

    /**
     * T10: Dump ETH priced to 1500 USD (Equity < IMR)
     */
    vm.warp(block.timestamp + 10);
    {
      //  Set Price for ETHUSD to 1,550 USD
      bytes32[] memory _assetIds = new bytes32[](4);
      _assetIds[0] = wethAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = daiAssetId;
      _assetIds[3] = wbtcAssetId;
      int64[] memory _prices = new int64[](4);
      _prices[0] = 1_500;
      _prices[1] = 1;
      _prices[2] = 1;
      _prices[3] = 20_000;

      setPrices(_assetIds, _prices);

      // Alice's Equity must be upper IMR level
      // Equity = 102545.80392652086, IMR = 2800.0098123438183
      assertTrue(
        uint256(calculator.getEquity(SUB_ACCOUNT, 0, 0)) > calculator.getIMR(SUB_ACCOUNT),
        "ALICE's Equity > ALICE's IMR?"
      );
    }

    /**
     * T11: Alice fully close SHORT ETHUSD position (Equity > IMR)
     */
    vm.warp(block.timestamp + 1);
    {
      uint256 buySizeE30 = 280_000.9812343818 * 1e30;
      bytes[] memory priceData = new bytes[](0);
      // marketBuy(ALICE, SUB_ACCOUNT_ID, wethMarketIndex, buySizeE30, TP_TOKEN, priceData); //@todo - still can't fully close here
    }

    /**
     * T12: Alice can withdraw collateral successfully
     */
    vm.warp(block.timestamp + 1);
    {
      // Alice withdraw 1(USD) of USDC
      bytes[] memory priceData = new bytes[](0);
      withdrawCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 1 * 1e6, priceData);
    }
  }
}
