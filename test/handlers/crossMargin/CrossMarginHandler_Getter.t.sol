// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";

contract CrossMarginHandler_Getter is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST CORRECTNESS
   */

  function testCorrectness_CrossMarginHandler_GetWithdrawOrders() external {
    assertEq(crossMarginHandler.getWithdrawOrders().length, 0);

    // Open 5 orders
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getWithdrawOrders().length, 5);

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getWithdrawOrders().length, 7);
  }

  function testCorrectness_CrossMarginHandler_GetActiveWithdrawOrders() external {
    assertEq(crossMarginHandler.getActiveWithdrawOrders(10, 0).length, 0);
    // Open 5 orders
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getActiveWithdrawOrders(10, 0).length, 5);

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getActiveWithdrawOrders(10, 0).length, 2);

    // open 9 more orders, total now 11 orders
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getActiveWithdrawOrders(20, 0).length, 11);

    // Try with pagination
    assertEq(crossMarginHandler.getActiveWithdrawOrders(4, 0).length, 4);
    assertEq(crossMarginHandler.getActiveWithdrawOrders(4, 4).length, 4);
    assertEq(crossMarginHandler.getActiveWithdrawOrders(4, 8).length, 3);

    // Check order id
    {
      ICrossMarginHandler.WithdrawOrder[] memory _orders;
      _orders = crossMarginHandler.getActiveWithdrawOrders(7, 0);
      for (uint256 i = 0; i < _orders.length; i++) {
        assertEq(_orders[i].orderId, crossMarginHandler.nextExecutionOrderIndex() + i);
      }

      _orders = crossMarginHandler.getActiveWithdrawOrders(7, 7);
      for (uint256 i = 0; i < _orders.length; i++) {
        assertEq(_orders[i].orderId, crossMarginHandler.nextExecutionOrderIndex() + 7 + i);
      }
    }
  }

  function testCorrectness_CrossMarginHandler_GetExecutedWithdrawOrders() external {
    address _subAccount = getSubAccount(ALICE, 1);

    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 10, 0).length, 0);
    // Open 5 orders
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 10, 0).length, 0); // still 0, not execute yet

    // Execute them, and open 2 more orders
    simulateExecuteWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 10, 0).length, 5);

    // open 9 more orders, total now 11 orders
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    simulateAliceCreateWithdrawOrder();
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 20, 0).length, 5);

    // Execute them
    simulateExecuteWithdrawOrder();
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 20, 0).length, 16);

    // Try with pagination
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 0).length, 3);
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 3).length, 3);
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 6).length, 3);
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 9).length, 3);
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 12).length, 3);
    assertEq(crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 3, 15).length, 1);

    // Check order id
    {
      ICrossMarginHandler.WithdrawOrder[] memory _orders;
      _orders = crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 7, 0);
      for (uint256 i = 0; i < _orders.length; i++) {
        assertEq(_orders[i].orderId, i);
      }

      _orders = crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 7, 7);
      for (uint256 i = 0; i < _orders.length; i++) {
        assertEq(_orders[i].orderId, 7 + i);
      }

      _orders = crossMarginHandler.getExecutedWithdrawOrders(_subAccount, 7, 14);
      for (uint256 i = 0; i < _orders.length; i++) {
        assertEq(_orders[i].orderId, 14 + i);
      }
    }
  }

  function testCorrectness_CrossMarginHandler_GetWithdrawOrders_TimestampCorrectness() external {
    dealyb(payable(address(ybeth)), ALICE, 10 ether);
    simulateAliceDepositToken(address(ybeth), (1.5 ether));

    vm.warp(block.timestamp + 100);

    // Open 2 orders
    simulateAliceCreateWithdrawOrder(); // Intention: success
    simulateAliceCreateWithdrawOrder(); // Intention: over-withdraw but success

    // assert timestamp and status
    {
      ICrossMarginHandler.WithdrawOrder[] memory _orders = crossMarginHandler.getActiveWithdrawOrders(2, 0);

      assertEq(_orders[0].orderId, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 0);
      assertEq(uint(_orders[0].status), 0); // pending

      assertEq(_orders[1].orderId, 1);
      assertEq(_orders[1].createdTimestamp, 101);
      assertEq(_orders[1].executedTimestamp, 0);
      assertEq(uint(_orders[1].status), 0); // pending
    }

    vm.warp(block.timestamp + 100);

    // Execute
    simulateExecuteWithdrawOrder();

    // assert timestamp and status
    {
      address _subAccount = getSubAccount(ALICE, 1);
      ICrossMarginHandler.WithdrawOrder[] memory _orders = crossMarginHandler.getExecutedWithdrawOrders(
        _subAccount,
        2,
        0
      );

      assertEq(_orders[0].orderId, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 201);
      assertEq(uint(_orders[0].status), 1); // success

      assertEq(_orders[1].orderId, 1);
      assertEq(_orders[1].createdTimestamp, 101);
      assertEq(_orders[1].executedTimestamp, 201);
      assertEq(uint(_orders[1].status), 1); // success
    }
  }
}
