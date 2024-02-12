// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginService_Base } from "./CrossMarginService_Base.t.sol";

// What is this test DONE
// - revert
//   - Try withdraw token collateral with not in whitelist
//   - Try withdraw token collaeral with not accepted token (Ex. Fx, Equity)
//   - Try withdraw token collateral with incufficent allowance
//   - Try withdraw token collateral with equity below IMR
// - success
//   - Try deposit and withdraw collateral with happy case
//   - Try deposit and withdraw collateral with happy case and check on token list of sub account
//   - Try deposit and withdraw multi tokens and checks on  token list of sub account

contract CrossMarginService_WithdrawCollateral is CrossMarginService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // Try withdraw token collateral with not in whitelist
  function testRevert_withdrawCollateral_onlyWhitelistedExecutor() external {
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotWhiteListed()"));
    crossMarginService.withdrawCollateral(address(this), 1, address(weth), 10 ether, address(this));
  }

  // Try withdraw token collaeral with not accepted token (Ex. Fx, Equity)
  function testRevert_withdrawCollateral_onlyAcceptedToken() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    crossMarginService.withdrawCollateral(address(this), 1, address(dai), 10 ether, address(this));
  }

  //  Try withdraw token collateral with incufficent allowance
  function testRevert_withdrawCollateral_InsufficientBalance() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()"));
    crossMarginService.withdrawCollateral(address(this), 1, address(ybeth), 10 ether, address(this));
  }

  // Try withdraw token collateral with equity below IMR
  function testRevert_withdrawCollateral_WithdrawBalanceBelowIMR() external {
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), (10 ether));

    // Mock calculator return values
    mockCalculator.setEquity(getSubAccount(ALICE, 1), 10 ether);
    mockCalculator.setIMR(getSubAccount(ALICE, 1), 12 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
    crossMarginService.withdrawCollateral(ALICE, 1, address(ybeth), 10 ether, address(this));
    vm.stopPrank();
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try deposit and withdraw collateral with happy case, and verify behavior of receiver param
  function testCorrectness_withdrawCollateral() external {
    // Before start depositing, ALICE must has 0 amount of ybETH token
    assertEq(vaultStorage.traderBalances(ALICE, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    // Deposit 10 ybETH
    simulateAliceDepositToken(address(ybeth), (10 ether));

    // After deposited, ALICE must have 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(getSubAccount(ALICE, 1), address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // Withdraw 3 ybETH
    simulateAliceWithdrawToken(address(ybeth), 3 ether);

    // After withdrawn, ALICE must have 7 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(getSubAccount(ALICE, 1), address(ybeth)), 7 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(ybeth.balanceOf(ALICE), 3 ether);

    // Continue, withdraw 2.5 ybETH, but this time receiver = Bob
    vm.startPrank(ALICE);
    crossMarginService.withdrawCollateral(ALICE, 1, address(ybeth), 2.5 ether, BOB);
    vm.stopPrank();

    // After withdrawn, ALICE must have 4.5 ybETH as collateral token
    // But, ALICE balance must remain the same, as 2.5 ybETH should go to BOB
    assertEq(vaultStorage.traderBalances(getSubAccount(ALICE, 1), address(ybeth)), 4.5 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 4.5 ether);
    assertEq(ybeth.balanceOf(ALICE), 3 ether);
    assertEq(ybeth.balanceOf(BOB), 2.5 ether);
  }

  // Try deposit and withdraw collateral with happy case and check on token list of sub account
  function testCorrectness_withdrawCollateral_traderTokenList_singleToken() external {
    // Before ALICE start depositing, token lists must contains no token
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 0);

    // ALICE deposits first time
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), (10 ether));

    // After ALICE start depositing, token lists must contains 1 token
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 1);

    // ALICE try withdrawing some of ybETH from Vault
    simulateAliceWithdrawToken(address(ybeth), 3 ether);

    // After ALICE withdrawn some of ybETH, list of token must still contain ybETH
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 1);

    // ALICE try withdrawing all of ybETH from Vault
    simulateAliceWithdrawToken(address(ybeth), 7 ether);
    assertEq(vaultStorage.traderBalances(getSubAccount(ALICE, 1), address(ybeth)), 0 ether);
    assertEq(ybeth.balanceOf(ALICE), 10 ether);

    // After ALICE withdrawn all of ybETH, list of token must be 0
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 0);
  }

  // Try deposit and withdraw multi tokens and checks on  token list of sub account
  function testCorrectness_withdrawCollateral_traderTokenList_multiTokens() external {
    // ALICE deposits ybETH
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), 10 ether);

    // ALICE deposits USDC
    usdc.mint(ALICE, 10_000 * 1e6);
    simulateAliceDepositToken(address(usdc), 10_000 * 1e6);

    // After ALICE start depositing, token lists must contains 2 tokens
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 2);

    // ALICE try withdrawing all of ybETH from Vault
    simulateAliceWithdrawToken(address(ybeth), 10 ether);

    // After ALICE withdrawn all of ybETH, list of token must still contain USDC
    assertEq(vaultStorage.getTraderTokens(getSubAccount(ALICE, 1)).length, 1);
  }
}
