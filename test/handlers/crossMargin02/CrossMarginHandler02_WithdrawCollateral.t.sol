// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CrossMarginHandler02_Base, IPerpStorage } from "./CrossMarginHandler02_Base.t.sol";

import { MockAccountAbstraction } from "../../mocks/MockAccountAbstraction.sol";

// What is this test DONE
// - revert
//   - Try withdraw token collateral with not accepted token (Ex. Fx, Equity)
//   - Try withdraw token collateral with insufficient allowance
// - success
//   - Try deposit and withdraw collateral with happy case
//   - Try deposit and withdraw collateral with happy case and check on token list of sub account
//   - Try deposit and withdraw multi tokens and checks on  token list of sub account

contract CrossMarginHandler02_WithdrawCollateral is CrossMarginHandler02_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST CORRECTNESS
   */

  function testCorrectness_Handler02_WhenWithdrawWETH() external {
    vm.startPrank(BOB, BOB);
    vm.deal(BOB, 20 ether);
    vm.stopPrank();

    address subAccount = getSubAccount(ALICE, SUB_ACCOUNT_NO);

    // Before start depositing, Alice must have 0 ybETH
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 0);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 0);
    assertEq(ybeth.balanceOf(ALICE), 0 ether);

    // Deposit 10 WETH (7 WETH, 3 ETH), all should wrapped to 10 ybETH
    {
      weth.mint(ALICE, 7 ether);
      simulateAliceDepositToken(address(weth), (7 ether));
      vm.deal(ALICE, 3 ether);
      vm.startPrank(ALICE);
      crossMarginHandler.depositCollateral{ value: 3 ether }(ALICE, SUB_ACCOUNT_NO, address(weth), 3 ether, true);
      vm.stopPrank();
    }

    // After deposited, Alice's sub account must have 10 ybETH as collateral token
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 10 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 10 ether);
    assertEq(weth.balanceOf(ALICE), 0 ether);

    simulateAliceWithdrawToken(address(weth), 3 ether, tickPrices, publishTimeDiffs, block.timestamp, false);

    // After withdrawn, Alice must have 7 ybETH as collateral token and 3 WETH in her wallet.
    assertEq(vaultStorage.traderBalances(subAccount, address(ybeth)), 7 ether);
    assertEq(ybeth.balanceOf(address(vaultStorage)), 7 ether);
    assertEq(weth.balanceOf(ALICE), 3 ether);

    // Try withdraw WETH, but with unwrap option
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

  function testCorrectness_Handler02_WhenRebased_WhenWithdrawWETH() external {
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

  function testCorrectness_Handler02_WhenWithdrawWETH_AssetTraderTokenList() external {
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

  function testCorrectness_Handler02_WhenUserCancelWithdrawOrder() external {
    // Open an order
    uint256 orderIndex = simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 1);
    // cancel, should have 0 active
    uint256 balanceBefore = ALICE.balance;
    vm.prank(ALICE);
    crossMarginHandler.cancelWithdrawOrder(ALICE, SUB_ACCOUNT_NO, orderIndex);
    assertEq(ALICE.balance - balanceBefore, 0.0001 ether);
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 0);
  }

  function testCorrectness_Handler02_WhenWithdrawOrderFail() external {
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 0);
    address[] memory accounts = new address[](1);
    uint8[] memory subAccountIds = new uint8[](1);
    uint256[] memory orderIndexes = new uint256[](1);
    // Open an order
    uint256 orderIndex = simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 1);

    accounts[0] = ALICE;
    subAccountIds[0] = SUB_ACCOUNT_NO;
    orderIndexes[0] = orderIndex;
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);

    assertEq(crossMarginHandler.getAllExecutedOrders(5, 0).length, 0);
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 0);
  }

  function testCorrectnes_Handler02_WhenWithdrawSuccess_AssertGas() external {
    assertEq(crossMarginHandler.getAllActiveOrders(1, 0).length, 0);

    address[] memory accounts = new address[](5);
    uint8[] memory subAccountIds = new uint8[](5);
    uint256[] memory orderIndexes = new uint256[](5);

    // Open 2, failed
    for (uint256 i = 0; i < 2; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }

    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    // Open 3, success
    for (uint256 i = 2; i < 5; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }

    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 5);

    // Execute them, and open 2 more orders
    // total fee = 5 * 0.0001 ETH = 0.0005 ETH
    uint256 balanceBefore = FEEVER.balance;
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 0);
    uint256 receivedFee = FEEVER.balance - balanceBefore;
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 5);
    assertEq(receivedFee, 0.0005 ether);
  }

  function testCorrectnes_Handler02_WhenDelegate() external {
    assertEq(crossMarginHandler.getAllActiveOrders(1, 0).length, 0);

    address delegatee = makeAddr("aliceDelegatee");

    vm.prank(ALICE);
    crossMarginHandler.setDelegate(delegatee);
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    address[] memory accounts = new address[](5);
    uint8[] memory subAccountIds = new uint8[](5);
    uint256[] memory orderIndexes = new uint256[](5);

    // Open 5 orders
    for (uint256 i = 0; i < 5; i++) {
      vm.deal(delegatee, 0.0001 ether);
      vm.prank(delegatee);
      uint256 orderIndex = crossMarginHandler.createWithdrawCollateralOrder{ value: 0.0001 ether }(
        ALICE,
        SUB_ACCOUNT_NO,
        address(weth),
        1 ether,
        0.0001 ether,
        false
      );

      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }

    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 5);

    uint256 balanceBeforeDel = weth.balanceOf(delegatee);
    uint256 balanceBeforeAl = weth.balanceOf(ALICE);

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);

    uint256 balanceAfterDel = weth.balanceOf(delegatee);
    uint256 balanceAfterAl = weth.balanceOf(ALICE);

    assertEq(balanceAfterAl - balanceBeforeAl, 5 ether);
    assertEq(balanceAfterDel, balanceBeforeDel);
    // assertEq(balanceBeforeDel, balanceAfterDel);

    assertEq(crossMarginHandler.getAllExecutedOrders(5, 0).length, 5);
  }
}
