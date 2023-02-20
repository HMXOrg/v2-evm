// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

// What is this test DONE
// - revert
//   - Try withdraw token collaeral with not accepted token (Ex. Fx, Equity)
//   - Try withdraw token collateral with incufficent allowance
//   - Try withdraw token collateral with equity below IMR
// - success
//   - Try deposit and withdraw collateral with happy case
//   - Try deposit and withdraw collateral with happy case and check on token list of sub account
//   - Try deposit and withdraw multi tokens and checks on  token list of sub account

contract CrossMarginService_WithdrawCollateral is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST REVERT
   */

  // Try withdraw token collaeral with not accepted token (Ex. Fx, Equity)
  function testRevert_handler_withdrawCollateral_onlyAcceptedToken() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("NotAcceptedCollateral()"));
    crossMarginHandler.withdrawCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(dai),
      10 ether
    );
  }

  //  Try withdraw token collateral with incufficent allowance
  function testRevert_handler_withdrawCollateral_InsufficientBalance()
    external
  {
    vm.prank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()")
    );
    crossMarginHandler.withdrawCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(weth),
      10 ether
    );
  }

  // Try withdraw token collateral with equity below IMR
  function testRevert_handler_withdrawCollateral_WithdrawBalanceBelowIMR()
    external
  {
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), (10 ether));

    // Mock calculator return values
    mockCalculator.setEquity(10 ether);
    mockCalculator.setIMR(12 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()")
    );
    crossMarginHandler.withdrawCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(weth),
      10 ether
    );
    vm.stopPrank();
  }

  /**
   * TEST CORRECTNESS
   */

  // Try deposit and withdraw collateral with happy case
  function testCorrectness_handler_withdrawCollateral() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), (10 ether));

    // After deposited, ALICE's sub account must has 10 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 10 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    simulateAliceWithdrawToken(address(weth), 3 ether);

    // After withdrawn, ALICE must has 7 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 7 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);
  }

  // Try deposit and withdraw collateral with happy case and check on token list of sub account
  function testCorrectness_handler_withdrawCollateral_traderTokenList_singleToken()
    external
  {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), (10 ether));

    // After ALICE start depositing, token lists must contains 1 token
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 1);

    // ALICE try withdrawing some of WETH from Vault
    simulateAliceWithdrawToken(address(weth), 3 ether);

    // After ALICE withdrawn some of WETH, list of token must still contain WETH
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 1);

    // ALICE try withdrawing all of WETH from Vault
    simulateAliceWithdrawToken(address(weth), 7 ether);
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0 ether);
    assertEq(weth.balanceOf(ALICE), 10 ether);

    // After ALICE withdrawn all of WETH, list of token must be 0
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 0);
  }

  // Try deposit and withdraw multi tokens and checks on  token list of sub account
  function testCorrectness_handler_withdrawCollateral_traderTokenList_multiTokens()
    external
  {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // ALICE deposits WETH
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // ALICE deposits USDC
    usdc.mint(ALICE, 10_000 * 1e6);
    simulateAliceDepositToken(address(usdc), 10_000 * 1e6);

    // After ALICE start depositing, token lists must contains 2 tokens
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 2);

    // ALICE try withdrawing all of WETH from Vault
    simulateAliceWithdrawToken(address(weth), 10 ether);

    // After ALICE withdrawn all of WETH, list of token must still contain USDC
    assertEq(vaultStorage.getTraderTokens(subAccount).length, 1);
  }
}
