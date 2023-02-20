// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

// What is this test DONE
// - revert
//   - Try deposit token collaeral with not accepted token (Ex. Fx, Equity)
//   - Try deposit token collateral with incufficent allowance
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

  // Try deposit token collaeral with not accepted token (Ex. Fx, Equity)
  function testRevert_handler_depositCollateral_onlyAcceptedToken() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("NotAcceptedCollateral()"));
    crossMarginHandler.depositCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(dai),
      10 ether
    );
  }

  // Try deposit token collateral with incufficent allowance
  function testRevert_handler_depositCollateral_InsufficientAllowance()
    external
  {
    vm.prank(ALICE);
    vm.expectRevert("ERC20: insufficient allowance");
    crossMarginHandler.depositCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(weth),
      10 ether
    );
  }

  // Try deposit token collateral with exceed trader's balance
  function testRevert_handler_depositCollateral_TransferExceedBalance()
    external
  {
    uint256 depositAmount = 10 ether;

    vm.startPrank(ALICE);
    weth.approve(address(crossMarginService), depositAmount);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    crossMarginHandler.depositCollateral(
      ALICE,
      SUB_ACCOUNT_NO,
      address(weth),
      depositAmount
    );
    vm.stopPrank();
  }

  /**
   * TEST CORRECTNESS
   */

  // Try deposit token collateral with initial balance and test accounting balance
  function testCorrectness_handler_handler_depositCollateral_newDepositingToken()
    external
  {
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
  function testCorrectness_handler_depositCollateral_newDepositingToken_traderTokenList()
    external
  {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(
      subAccount
    );
    assertEq(traderTokenBefore.length, 0);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(
      subAccount
    );
    assertEq(traderTokenAfter.length, 1);
  }

  // Try deposit token collateral with existing balance and test deposit token lists + balance
  function testCorrectness_handler_depositCollateral_oldDepositingToken_traderTokenList()
    external
  {
    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(
      subAccount
    );
    assertEq(traderTokenBefore.length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // ALICE deposits second time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(
      subAccount
    );
    assertEq(traderTokenAfter.length, 1);

    // After deposited, ALICE must has 20 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 20 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 20 ether);
    assertEq(weth.balanceOf(ALICE), 0);
  }
}
