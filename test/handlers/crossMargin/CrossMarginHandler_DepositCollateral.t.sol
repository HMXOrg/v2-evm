// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

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

  function testRevert_Handler_DepositCollateral_WhenDepositUnacceptedCollateral() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(dai), 10 ether, false);
  }

  function testRevert_Handler_DepositCollateral_WhenInsufficientAllowance() external {
    vm.startPrank(ALICE);
    vm.expectRevert("ERC20: insufficient allowance");
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(wbtc), 10 ether, false);
    vm.stopPrank();
  }

  function testRevert_Handler_DepositCollateral_WhenTransferExceedBalance() external {
    uint256 depositAmount = 10 ether;

    vm.startPrank(ALICE);
    wbtc.approve(address(crossMarginHandler), depositAmount);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(wbtc), depositAmount, false);
    vm.stopPrank();
  }

  function testRevert_Handler_DepositCollateral_WhenWrappedNative_WithBadMsgValue() external {
    vm.deal(ALICE, 20 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_MismatchMsgValue()"));
    // amount = 20 ether, but msg.value = 19 ether
    crossMarginHandler.depositCollateral{ value: 19 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();
  }

  // Try deposit native token as collateral, but has not enough native balance
  function testRevert_Handler_DepositCollateral_WhenNative_WithInsufficientNativeBalance() external {
    // Give Alice 19 ETH, but Alice will try to deposit 20 ETH
    vm.deal(ALICE, 19 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(); // EvmError: OutOfFund
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();
  }

  // Try deposit token with _shouldWrap = true, but with non-wNative token
  function testRevert_Handler_DepositCollateral_WhenShouldWrapTrue_ButWithNonWNativeToken() external {
    vm.deal(ALICE, 20 ether);

    vm.startPrank(ALICE);
    vm.expectRevert(); // EvmError: Revert (WBTC has no deposit func)
    // Alice will deposit with _shouldWrap = true, but input _address as WBTC (non-wNative).
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(wbtc), 20 ether, true);
    vm.stopPrank();
  }

  // Try deposit token when there're some exceeded tokens in the vault storage
  function testRevert_Handler_DepositCollateral_WhenSomeExceededTokens() external {
    wbtc.mint(ALICE, 1 * 1e8);
    wbtc.mint(address(vaultStorage), 10 * 1e8);

    vm.startPrank(ALICE);
    // Alice try deposit 1 WBTC, but there're 10 WBTC in the vault storage
    wbtc.approve(address(crossMarginHandler), 1 * 1e8);
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_InvalidDepositBalance()"));
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(wbtc), 1 * 1e8, false);
    vm.stopPrank();
  }

  /**
   * TEST CORRECTNESS
   */

  // Deposit collateral that's already yb or no need to wrap to yb
  function testCorrectness_Handler_DepositCollateral_SimpleDeposit() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must has 0 amount of ybETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);

    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), 10 ether);

    // After deposited, ALICE's sub account must has 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
  }

  // Deposit collateral that's already yb or no need to wrap to yb, assert trader token list
  function testCorrectness_Handler_DepositCollateral_SimpleDeposit_AssertTraderTokenList() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenBefore.length, 0);

    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenAfter.length, 1);
    assertEq(traderTokenAfter[0], address(ybeth));
  }

  // Deposit collateral twice and assert deposit token lists + balance
  function testCorrectness_Handler_DepositCollateral_SimpleDeposit_DepositSameAsset_AssertTraderTokenList() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenBefore.length, 0);

    // ALICE deposits first time
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), 10 ether);

    // ALICE deposits second time
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenAfter.length, 1);
    assertEq(traderTokenAfter[0], address(ybeth));

    // After deposited, ALICE must has 20 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 20 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(ybeth.balanceOf(ALICE), 0);
  }

  // Deposit collateral that's wrapable to yb, assert balance and trader token list
  function testCorrectness_Handler_DepositCollateral_WrapableDeposit() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenBefore.length, 0);

    // Alice deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // Alice deposits second time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After Alice's account
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(subAccount);
    assertEq(traderTokenAfter.length, 1);
    assertEq(traderTokenAfter[0], address(ybeth));

    // After deposited, ALICE must has 20 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 20 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(weth.balanceOf(ALICE), 0);
  }

  // Try deposit native token as collateral
  function testCorrectness_handler_depositEthAsCollateral_ShouldWrapToYbETH() external {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);

    vm.deal(ALICE, 20 ether);
    vm.startPrank(ALICE);
    crossMarginHandler.depositCollateral{ value: 20 ether }(SUB_ACCOUNT_NO, address(weth), 20 ether, true);
    vm.stopPrank();

    // After deposited, ALICE's sub account must has 20 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 20 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(ALICE.balance, 0 ether);
  }
}
