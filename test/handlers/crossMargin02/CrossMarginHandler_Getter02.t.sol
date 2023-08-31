// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { CrossMarginHandler_Base02 } from "./CrossMarginHandler_Base02.t.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { ICrossMarginHandler02 } from "@hmx/handlers/interfaces/ICrossMarginHandler02.sol";

import "forge-std/console.sol";

contract CrossMarginHandler_Getter is CrossMarginHandler_Base02 {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST CORRECTNESS
   */

  function testCorrectness_crossMarginHandler02_getAllActiveOrders() external {
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    assertEq(crossMarginHandler.getAllActiveOrders(1, 0).length, 0);

    address[] memory accounts = new address[](5);
    uint8[] memory subAccountIds = new uint8[](5);
    uint256[] memory orderIndexes = new uint256[](5);

    // Open 5 orders
    for (uint256 i = 0; i < 5; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }

    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 5);

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);

    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 5);

    accounts = new address[](2);
    subAccountIds = new uint8[](2);
    orderIndexes = new uint256[](2);

    for (uint256 i = 0; i < 2; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 2);
  }

  function testCorrectness_crossMarginHandler02_getActiveWithdrawOrders() external {
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 0);
    // Open 5 orders
    address[] memory accounts = new address[](5);
    uint8[] memory subAccountIds = new uint8[](5);
    uint256[] memory orderIndexes = new uint256[](5);

    // Open 5 orders
    for (uint256 i = 0; i < 5; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 5);
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 5);

    accounts = new address[](11);
    subAccountIds = new uint8[](11);
    orderIndexes = new uint256[](11);

    for (uint256 i = 0; i < 2; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 2);

    for (uint256 i = 2; i < 11; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    // open 9 more orders, total now 11 orders
    assertEq(crossMarginHandler.getAllActiveOrders(20, 0).length, 11);

    // Try with pagination
    assertEq(crossMarginHandler.getAllActiveOrders(4, 0).length, 4);
    assertEq(crossMarginHandler.getAllActiveOrders(4, 4).length, 4);
    assertEq(crossMarginHandler.getAllActiveOrders(4, 8).length, 3);
  }

  function testCorrectness_crossMarginHandler02_getAllExecutedOrders() external {
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), 10 ether);

    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 0);
    // Open 5 orders
    address[] memory accounts = new address[](5);
    uint8[] memory subAccountIds = new uint8[](5);
    uint256[] memory orderIndexes = new uint256[](5);

    // Open 5 orders
    for (uint256 i = 0; i < 5; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 5); // total 5, executed 0
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 0);

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 0);
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 5);

    accounts = new address[](5);
    subAccountIds = new uint8[](5);
    orderIndexes = new uint256[](5);

    for (uint256 i = 0; i < 2; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }

    // open 3 more orders, total now 5 orders
    for (uint256 i = 2; i < 5; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    assertEq(crossMarginHandler.getAllActiveOrders(10, 0).length, 5);
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 5);

    // Execute them
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);
    assertEq(crossMarginHandler.getAllExecutedOrders(10, 0).length, 10);

    // Try with pagination
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 0).length, 3);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 3).length, 3);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 6).length, 3);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 9).length, 1);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 12).length, 0);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 15).length, 0);
  }

  function testCorrectness_crossMarginHandler02_getWithdrawOrders_timestampCorrectness() external {
    weth.mint(ALICE, 10 ether);
    simulateAliceDepositToken(address(weth), (10 ether));

    vm.warp(block.timestamp + 100);

    address[] memory accounts = new address[](2);
    uint8[] memory subAccountIds = new uint8[](2);
    uint256[] memory orderIndexes = new uint256[](2);

    for (uint256 i = 0; i < 2; i++) {
      uint256 orderIndex = simulateAliceCreateWithdrawOrder();
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      orderIndexes[i] = orderIndex;
    }
    // assert timestamp and status
    {
      ICrossMarginHandler02.WithdrawOrder[] memory _orders = crossMarginHandler.getAllActiveOrders(2, 0);
      assertEq(_orders[0].orderIndex, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 0);
      assertEq(uint(_orders[0].status), 0); // pending

      assertEq(_orders[1].orderIndex, 1);
      assertEq(_orders[1].createdTimestamp, 101);
      assertEq(_orders[1].executedTimestamp, 0);
      assertEq(uint(_orders[1].status), 0); // pending
    }

    vm.warp(block.timestamp + 100);
    // Execute
    simulateExecuteWithdrawOrder(accounts, subAccountIds, orderIndexes);
    assertEq(crossMarginHandler.getAllExecutedOrders(3, 0).length, 2);

    // assert timestamp and status
    {
      ICrossMarginHandler02.WithdrawOrder[] memory _orders = crossMarginHandler.getAllExecutedOrders(2, 0);

      assertEq(_orders[0].orderIndex, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 201);
      assertEq(uint(_orders[0].status), 1); // success

      assertEq(_orders[1].orderIndex, 1);
      assertEq(_orders[1].createdTimestamp, 101);
      assertEq(_orders[1].executedTimestamp, 201);
      assertEq(uint(_orders[1].status), 1); // success
    }
  }

  function testCorrectness_handler02_userCancelOrder() external {
    // Open an order
    uint256 orderIndex = simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 1);
    ICrossMarginHandler02.WithdrawOrder[] memory _orders = crossMarginHandler.getAllActiveOrders(2, 0);
    // cancel, should have 0 active
    vm.prank(ALICE);
    crossMarginHandler.cancelWithdrawOrder(ALICE, SUB_ACCOUNT_NO, orderIndex);
    _orders = crossMarginHandler.getAllActiveOrders(2, 0);
    assertEq(crossMarginHandler.getAllActiveOrders(5, 0).length, 0);
  }

  function testCorrectness_handler02_cancelOrderWhenFail() external {
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

  function testCorrectnes_handler02_receiverGetFee() external {
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
}
