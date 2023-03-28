// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { CrossMarginHandler_Base, MockErc20 } from "./CrossMarginHandler_Base.t.sol";

// What is this test DONE
// - revert
//   - Try deposit token collateral with not accepted token (Ex. Fx, Equity)
//   - Try deposit token collateral with insufficient allowance
//   - Try deposit token collateral with exceed trader's balance
// - success
//   - Try deposit token collateral with initial balance and test accounting balance
//   - Try deposit token collateral with initial balance and test deposit token lists
//   - Try deposit token collateral with existing balance and test deposit token lists + balance

contract CrossMarginHandler_DepositCollateral is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST REVERT
   */

  // Try deposit token collateral with not accepted token (Ex. Fx, Equity)
  function testRevert_handler_depositCollateral_onlyAcceptedToken() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(dai), 10 ether, false);
  }

  // Try deposit token collateral with insufficient allowance
  function testRevert_handler_depositCollateral_InsufficientAllowance() external {
    vm.startPrank(ALICE);
    vm.expectRevert("ERC20: insufficient allowance");
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(wbtc), 10 ether, false);
    vm.stopPrank();
  }

  // Try deposit token collateral with exceed trader's balance
  function testRevert_handler_depositCollateral_TransferExceedBalance() external {
    uint256 depositAmount = 10 ether;

    vm.startPrank(ALICE);
    wbtc.approve(address(crossMarginHandler), depositAmount);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(wbtc), depositAmount, false);
    vm.stopPrank();
  }

  // Try deposit native token as collateral, but with mismatch msg.value
  function testRevert_handler_depositCollateral_wNativeToken_withBadMsgValue() external {
    vm.deal(ALICE, 20 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_MismatchMsgValue()"));
    // amount = 20 ether, but msg.value = 19 ether
    crossMarginHandler.depositCollateral{ value: 19 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();
  }

  // Try deposit native token as collateral, but has not enough native balance
  function testRevert_handler_depositCollateral_wNativeToken_withInsufficientNativeBalance() external {
    // Give Alice 19 ETH, but Alice will try to deposit 20 ETH
    vm.deal(ALICE, 19 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(); // EvmError: OutOfFund
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();
  }

  // Try deposit token with _shouldWrap = true, but with non-wNative token
  function testRevert_handler_depositCollateral_withShouldWrap_butWithNonWNativeToken() external {
    vm.deal(ALICE, 20 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(); // EvmError: Revert (WBTC has no deposit func)
    // Alice will deposit with _shouldWrap = true, but input _address as WBTC (non-wNative).
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(wbtc), 20 ether, true);
    vm.stopPrank();
  }

  /**
   * TEST CORRECTNESS
   */

  // Try deposit token collateral with initial balance and test accounting balance
  function testCorrectness_handler_depositCollateral_newDepositingToken() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After deposited, ALICE's sub account must has 10 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 10 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 10 ether);
  }

  // Try deposit token collateral with initial balance and test deposit token lists
  function testCorrectness_handler_depositCollateral_newDepositingToken_traderTokenList() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenBefore.length, 0);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenAfter.length, 1);
  }

  // Try deposit token collateral with existing balance and test deposit token lists + balance
  function testCorrectness_handler_depositCollateral_oldDepositingToken_traderTokenList() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenBefore.length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // ALICE deposits second time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenAfter.length, 1);

    // After deposited, ALICE must has 20 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 20 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(weth.balanceOf(ALICE), 0);
  }

  // Try deposit native token as collateral
  function testCorrectness_handler_depositCollateral_wNativeToken() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);

    vm.deal(ALICE, 20 ether);
    vm.startPrank(ALICE);
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();

    // After deposited, ALICE's sub account must has 20 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 20 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(ALICE.balance, 0 ether);
  }
}
