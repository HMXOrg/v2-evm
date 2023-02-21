// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginService_Base } from "./CrossMarginService_Base.t.sol";

// What is this test DONE
// - revert
//   - Try deposit token collateral with not in whitelist
//   - Try deposit token collaeral with not accepted token (Ex. Fx, Equity)
//   - Try deposit token collateral with incufficent allowance
//   - Try deposit token collateral with exceed trader's balance
// - success
//   - Try deposit token collateral with initial balance and test accounting balance
//   - Try deposit token collateral with initial balance and test deposit token lists
//   - Try deposit token collateral with existing balance and test deposit token lists + balance

contract CrossMarginService_DepositCollateral is CrossMarginService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  // Try deposit token collateral with not in whitelist
  function testRevert_depositCollateral_onlyWhitelistedExecutor() external {
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotWhiteListed()"));
    crossMarginService.depositCollateral(address(this), address(weth), 10 ether);
  }

  // Try deposit token collaeral with not accepted token (Ex. Fx, Equity)
  function testRevert_depositCollateral_onlyAcceptedToken() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    crossMarginService.depositCollateral(address(this), address(dai), 10 ether);
  }

  // Try deposit token collateral with incufficent allowance
  function testRevert_depositCollateral_InsufficientAllowance() external {
    vm.prank(CROSS_MARGIN_HANDLER);
    vm.expectRevert("ERC20: insufficient allowance");
    crossMarginService.depositCollateral(address(this), address(wbtc), 10 ether);
  }

  // Try deposit token collateral with exceed trader's balance
  function testRevert_depositCollateral_TransferExceedBalance() external {
    uint256 depositAmount = 10 ether;

    vm.startPrank(CROSS_MARGIN_HANDLER);
    wbtc.approve(address(crossMarginService), depositAmount);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    crossMarginService.depositCollateral(address(this), address(wbtc), depositAmount);
    vm.stopPrank();
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  // Try deposit token collateral with initial balance and test accounting balance
  function testCorrectness_depositCollateral_newDepositingToken() external {
    // Before start depositing, ALICE must has 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After deposited, ALICE must has 10 WETH as collateral token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 10 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 10 ether);
  }

  // Try deposit token collateral with initial balance and test deposit token lists
  function testCorrectness_depositCollateral_newDepositingToken_traderTokenList() external {
    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(ALICE);
    assertEq(traderTokenBefore.length, 0);

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(ALICE);
    assertEq(traderTokenAfter.length, 1);
  }

  // Try deposit token collateral with existing balance and test deposit token lists + balance
  function testCorrectness_depositCollateral_oldDepositingToken_traderTokenList() external {
    // Before ALICE start depositing, token lists must contains no token
    address[] memory traderTokenBefore = vaultStorage.getTraderTokens(ALICE);
    assertEq(traderTokenBefore.length, 0);

    // ALICE deposits first time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // ALICE deposits second time
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // After ALICE start depositing, token lists must contains 1 token
    address[] memory traderTokenAfter = vaultStorage.getTraderTokens(ALICE);
    assertEq(traderTokenAfter.length, 1);

    // After deposited, ALICE must has 20 WETH as collateral token
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), 20 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 20 ether);
  }
}
