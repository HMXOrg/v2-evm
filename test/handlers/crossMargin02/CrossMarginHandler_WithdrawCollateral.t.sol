// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CrossMarginHandler_Base02, IPerpStorage } from "./CrossMarginHandler_Base02.t.sol";

// What is this test DONE
// - revert
//   - Try withdraw token collateral with not accepted token (Ex. Fx, Equity)
//   - Try withdraw token collateral with insufficient allowance
// - success
//   - Try deposit and withdraw collateral with happy case
//   - Try deposit and withdraw collateral with happy case and check on token list of sub account
//   - Try deposit and withdraw multi tokens and checks on  token list of sub account

contract CrossMarginHandler_WithdrawCollateral is CrossMarginHandler_Base02 {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST CORRECTNESS
   */

  // Try deposit and withdraw collateral with happy case
  function testCorrectness_handler02_withdrawCollateral() external {
    vm.startPrank(BOB, BOB);
    vm.deal(BOB, 20 ether);
    vm.stopPrank();

    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, ALICE must have 0 amount of WETH token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
    assertEq(weth.balanceOf(address(vaultStorage)), 0);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    // Deposit 10 WETH (7 WETH, 3 ETH)
    {
      weth.mint(ALICE, 7 ether);
      simulateAliceDepositToken(address(weth), (7 ether));
      vm.deal(ALICE, 3 ether);
      vm.startPrank(ALICE);
      crossMarginHandler.depositCollateral{ value: 3 ether }(SUB_ACCOUNT_NO, address(weth), 3 ether, true);
      vm.stopPrank();
    }

    // After deposited, ALICE's sub account must have 10 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 10 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    simulateAliceWithdrawToken(address(weth), 3 ether, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, ALICE must have 7 WETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 7 ether);
    assertEq(weth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);

    // Try withdraw WETH, but with unwrap option
    simulateAliceWithdrawToken(address(weth), 1.5 ether, tickPrices, publishTimeDiffs, block.timestamp, true);

    // After withdrawn with unwrap,
    // - Vault must have 5.5 WETH
    // - ALICE must have 5.5 WETH as collateral token
    // - ALICE must have 3 WETH in her wallet (as before)
    // - ALICE must have 1.5 ETH in her wallet (native token)
    assertEq(weth.balanceOf(address(vaultStorage)), 5.5 ether);
    assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 5.5 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);
    assertEq(ALICE.balance, 1.5 ether);
  }

  // Try deposit and withdraw collateral with happy case and check on token list of sub account
  function testCorrectness_handler02_withdrawCollateral_traderTokenList_singleToken() external {
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
