// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CrossMarginHandler_Base, IPerpStorage } from "./CrossMarginHandler_Base.t.sol";

// What is this test DONE
// - revert
//   - Try withdraw token collateral with not accepted token (Ex. Fx, Equity)
//   - Try withdraw token collateral with insufficient allowance
// - success
//   - Try deposit and withdraw collateral with happy case
//   - Try deposit and withdraw collateral with happy case and check on token list of sub account
//   - Try deposit and withdraw multi tokens and checks on  token list of sub account

contract CrossMarginHandler_WithdrawCollateral is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_Handler_WhenWithdrawWETH() external {
    vm.startPrank(BOB, BOB);
    vm.deal(BOB, 20 ether);
    vm.stopPrank();

    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, Alice must have 0 amount of ybETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // Deposit 10 WETH (7 WETH, 3 ETH), all should wrapped to 10 ybETH
    {
      weth.mint(ALICE, 7 ether);
      simulateAliceDepositToken(address(weth), (7 ether));
      vm.deal(ALICE, 3 ether);
      vm.startPrank(ALICE);
      crossMarginHandler.depositCollateral{ value: 3 ether }(SUB_ACCOUNT_NO, address(weth), 3 ether, true);
      vm.stopPrank();
    }

    // After deposited, Alice's sub account must have 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    // Alice try to withdraw 3 WETH. The protocol should unwrap ybETH to 3 WETH and send it to Alice
    simulateAliceWithdrawToken(address(weth), 3 ether, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, Alice must have 7 ybETH as collateral token and 3 WETH in her wallet.
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 7 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);

    // Try withdraw 1.5 WETH, but with unwrap option.
    simulateAliceWithdrawToken(address(weth), 1.5 ether, tickPrices, publishTimeDiffs, block.timestamp, true);

    // After withdrawn with unwrap,
    // - Vault must have 5.5 ybETH
    // - Alice must have 5.5 ybETH as collateral token
    // - Alice must have 3 WETH in her wallet (as before)
    // - Alice must have 1.5 ETH in her wallet (native token)
    assertEq(ybeth.balanceOf(address(vaultStorage)), 5.5 ether);
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 5.5 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);
    assertEq(ALICE.balance, 1.5 ether);
  }

  function testCorrectness_Handler_WhenRebased_WhenWithdrawWETH() external {
    vm.startPrank(BOB, BOB);
    vm.deal(BOB, 20 ether);
    vm.stopPrank();

    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, Alice must have 0 amount of ybETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // Deposit 10 WETH, all should wrapped to 10 ybETH
    {
      weth.mint(ALICE, 10 ether);
      simulateAliceDepositToken(address(weth), (10 ether));
    }

    // After deposited, Alice's sub account must have 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // WETH is rebased.
    weth.setNextYield(10 ether);

    // Alice try to withdraw 20 WETH, as now 1 ybETH = 2 WETH.
    // The protocol should unwrap ybETH to 20 WETH and send it to Alice correctly.
    simulateAliceWithdrawToken(address(weth), 20 ether, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, Alice must have 0 ybETH as collateral token and 20 WETH in her wallet.
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(weth.balanceOf(ALICE), 20 ether);
  }

  function testCorrectness_Handler_WhenRebased_WhenOverWithdrawWETH() external {
    vm.startPrank(BOB, BOB);
    vm.deal(BOB, 20 ether);
    vm.stopPrank();

    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, Alice must have 0 amount of ybETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // Deposit 10 WETH, all should wrapped to 10 ybETH
    {
      weth.mint(ALICE, 10 ether);
      simulateAliceDepositToken(address(weth), (10 ether));
    }

    // After deposited, Alice's sub account must have 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // WETH is rebased.
    weth.setNextYield(10 ether);

    // Alice try to withdraw 30 WETH, as now 1 ybETH = 2 WETH.
    // The protocol should unwrap ybETH to 20 WETH and send it to Alice correctly.
    simulateAliceWithdrawToken(address(weth), 30 ether, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, Alice must have 0 ybETH as collateral token and 20 WETH in her wallet.
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(weth.balanceOf(ALICE), 20 ether);
  }

  function testCorrectness_Handler_WhenWithdrawNormalErc20() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, Alice must have 0 amount of USDC
    assertEq(vaultStorage.traderBalances(subAccount, address(usdc)), 0);
    assertEq(usdc.balanceOf(address(vaultStorage)), 0);
    assertEq(usdc.balanceOf(ALICE), 0 ether);

    // Deposit 1_000 USDC
    {
      usdc.mint(ALICE, 1_000 * 1e6);
      simulateAliceDepositToken(address(usdc), 1_000 * 1e6);
    }

    // After deposited, Alice's sub account must have 1_000 USDC as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(usdc)), 1_000 * 1e6);
    assertEq(usdc.balanceOf(address(vaultStorage)), 1_000 * 1e6);
    assertEq(usdc.balanceOf(ALICE), 0);

    // Alice try to withdraw 300 USDC. The protocol should return 300 USDC to Alice
    simulateAliceWithdrawToken(address(usdc), 300 * 1e6, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, Alice must have 700 USDC as collaterals and 300 USDC in her wallet.
    assertEq(vaultStorage.traderBalances(subAccount, address(usdc)), 700 * 1e6);
    assertEq(usdc.balanceOf(address(vaultStorage)), 700 * 1e6);
    assertEq(usdc.balanceOf(ALICE), 300 * 1e6);
  }

  function testCorrectness_Handler_WhenWithdrawWETH_AssetTraderTokenList() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), (10 ether));
    assertEq(weth.balanceOf(ALICE), 0);

    // After ALICE start depositing, token lists must contains 1 token
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 1);

    // ALICE try withdrawing some of WETH from Vault
    simulateAliceWithdrawToken(address(weth), 3 ether, tickPrices, publishTimeDiffs, block.timestamp, false);
    assertEq(weth.balanceOf(ALICE), 3 ether);

    // After ALICE withdrawn some of WETH, list of token must still contain WETH
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 1);

    // ALICE try withdrawing all of WETH from Vault
    simulateAliceWithdrawToken(address(weth), 7 ether, tickPrices, publishTimeDiffs, block.timestamp, false);
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0 ether, "ALICE's WETH balance");
    assertEq(weth.balanceOf(ALICE), 10 ether);

    // After ALICE withdrawn all of WETH, list of token must be 0
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 0);
  }
}
