// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginService_Base } from "./CrossMarginService_Base.t.sol";

contract CrossMarginService_WithdrawCollateral is CrossMarginService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  function testRevert_withdrawCollateral_onlyWhitelistedExecutor() external {
    vm.expectRevert(abi.encodeWithSignature("NotWhiteListed()"));
    crossMarginService.withdrawCollateral(
      address(this),
      address(weth),
      10 ether
    );
  }

  function testRevert_withdrawCollateral_onlyAcceptedToken() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert(abi.encodeWithSignature("NotAcceptedCollateral()"));
    crossMarginService.withdrawCollateral(
      address(this),
      address(dai),
      10 ether
    );
  }

  function testRevert_withdrawCollateral_InsufficientBalance() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()")
    );
    crossMarginService.withdrawCollateral(
      address(this),
      address(weth),
      10 ether
    );
  }

  function testRevert_withdrawCollateral_WithdrawBalanceBelowIMR() external {
    weth.mint(ALICE, 10 ether);
    simulate_alice_deposit_token(address(weth), (10 ether));

    // Mock calculator return values
    mockCalculator.setEquity(10 ether);
    mockCalculator.setIMR(12 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()")
    );
    crossMarginService.withdrawCollateral(ALICE, address(weth), 10 ether);
    vm.stopPrank();
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_withdrawCollateral() external {
    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    weth.mint(ALICE, 10 ether);
    simulate_alice_deposit_token(address(weth), (10 ether));

    // After deposited, ALICE must has 10 WETH as collateral token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 10 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    simulate_alice_withdraw_token(address(weth), 3 ether);

    // After withdrawn, ALICE must has 7 WETH as collateral token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 7 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);
  }

  function testCorrectness_withdrawCollateral_traderTokenList_singleToken()
    external
  {
    // Before ALICE start depositing, token lists must contains no token
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulate_alice_deposit_token(address(weth), (10 ether));

    // After ALICE start depositing, token lists must contains 1 token
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 1);

    // ALICE try withdrawing some of WETH from Vault
    simulate_alice_withdraw_token(address(weth), 3 ether);

    // After ALICE withdrawn some of WETH, list of token must still contain WETH
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 1);

    // ALICE try withdrawing all of WETH from Vault
    simulate_alice_withdraw_token(address(weth), 7 ether);
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 0 ether);
    assertEq(weth.balanceOf(ALICE), 10 ether);

    // After ALICE withdrawn all of WETH, list of token must be 0
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 0);
  }

  function testCorrectness_withdrawCollateral_traderTokenList_multiTokens()
    external
  {
    // ALICE deposits WETH
    weth.mint(ALICE, 10 ether);
    simulate_alice_deposit_token(address(weth), 10 ether);

    // ALICE deposits USDC
    usdc.mint(ALICE, 10_000 * 1e6);
    simulate_alice_deposit_token(address(usdc), 10_000 * 1e6);

    // After ALICE start depositing, token lists must contains 2 tokens
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 2);

    // ALICE try withdrawing all of WETH from Vault
    simulate_alice_withdraw_token(address(weth), 10 ether);

    // After ALICE withdrawn all of WETH, list of token must still contain USDC
    assertEq(vaultStorage.getTraderTokens(ALICE).length, 1);
  }
}
