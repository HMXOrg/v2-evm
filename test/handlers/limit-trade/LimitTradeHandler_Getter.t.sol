// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - success
//   - Try set tradeService
//   - Try set min execution
//   - Try set Pyth address
//   - Try set order executor

contract LimitTradeHandler_Getter is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();

    vm.deal(ALICE, 100 ether);

    // Randomly create orders
    // 8 limit orders - sub#0 5, sub#1 3
    // 13 market orders - sub#0 9, sub#1 3, sub#2 1
    _createLimitOrder(0);
    _createLimitOrder(0);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createLimitOrder(0);
    _createLimitOrder(0);
    _createMarketOrder(0);
    _createLimitOrder(0);
    _createLimitOrder(1);
    _createLimitOrder(1);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createMarketOrder(0);
    _createLimitOrder(1);
    _createMarketOrder(1);
    _createMarketOrder(1);
    _createMarketOrder(1);
    _createMarketOrder(2);
  }

  function _createLimitOrder(uint8 _subAccountId) internal {
    vm.prank(ALICE);
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _mainAccount: ALICE,
      _subAccountId: _subAccountId,
      _marketIndex: 1,
      _sizeDelta: 100,
      _triggerPrice: 2e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });
  }

  function _createMarketOrder(uint8 _subAccountId) internal {
    vm.prank(ALICE);
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _mainAccount: ALICE,
      _subAccountId: _subAccountId,
      _marketIndex: 1,
      _sizeDelta: 100,
      _triggerPrice: 0,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });
  }

  function _cancelOrder(uint256 _orderIndex, uint8 _subAccountId) internal {
    vm.prank(ALICE);
    limitTradeHandler.cancelOrder({ _mainAccount: ALICE, _subAccountId: _subAccountId, _orderIndex: _orderIndex });
  }

  // Set trade service with zero address
  function testCorrectness_getAllActiveOrders() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;
    {
      _orders = limitTradeHandler.getAllActiveOrders(5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrders(5, 5);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrders(5, 10);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrders(5, 15);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrders(5, 20);
      assertEq(_orders.length, 1);
      _orders = limitTradeHandler.getAllActiveOrders(5, 25);
      assertEq(_orders.length, 0);
    }

    {
      _orders = limitTradeHandler.getAllActiveOrders(100, 0);
      assertEq(_orders.length, 21);

      _cancelOrder(0, 0);

      _orders = limitTradeHandler.getAllActiveOrders(100, 0);
      assertEq(_orders.length, 20);

      _cancelOrder(3, 0);
      _cancelOrder(4, 0);

      _orders = limitTradeHandler.getAllActiveOrders(100, 0);
      assertEq(_orders.length, 18);
    }
  }

  function testCorrectness_getMarketActiveOrders() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;
    {
      _orders = limitTradeHandler.getMarketActiveOrders(5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getMarketActiveOrders(5, 5);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getMarketActiveOrders(5, 10);
      assertEq(_orders.length, 3);
      _orders = limitTradeHandler.getMarketActiveOrders(5, 15);
      assertEq(_orders.length, 0);
    }

    {
      _orders = limitTradeHandler.getMarketActiveOrders(100, 0);
      assertEq(_orders.length, 13);

      // cancel order 0 (limit)
      _cancelOrder(0, 0);

      // should not change
      _orders = limitTradeHandler.getMarketActiveOrders(100, 0);
      assertEq(_orders.length, 13);

      // cancel order 3, 4 (both are market)
      _cancelOrder(3, 0);
      _cancelOrder(4, 0);

      _orders = limitTradeHandler.getMarketActiveOrders(100, 0);
      assertEq(_orders.length, 11);
    }
  }

  function testCorrectness_getLimitActiveOrders() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;
    {
      _orders = limitTradeHandler.getLimitActiveOrders(5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getLimitActiveOrders(5, 5);
      assertEq(_orders.length, 3);
      _orders = limitTradeHandler.getLimitActiveOrders(5, 10);
      assertEq(_orders.length, 0);
    }

    {
      _orders = limitTradeHandler.getLimitActiveOrders(100, 0);
      assertEq(_orders.length, 8);

      // cancel order 0 (limit)
      _cancelOrder(0, 0);

      _orders = limitTradeHandler.getLimitActiveOrders(100, 0);
      assertEq(_orders.length, 7);

      // cancel order 3, 4 (both are market)
      _cancelOrder(3, 0);
      _cancelOrder(4, 0);

      // should not change
      _orders = limitTradeHandler.getLimitActiveOrders(100, 0);
      assertEq(_orders.length, 7);
    }
  }

  function testCorrectness_getAllActiveOrdersBySubAccount() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;

    // SubAccount#0
    {
      // Total
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 14);

      // Pagination
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 5);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 10);
      assertEq(_orders.length, 4);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 15);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(0, 0);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 13);

      _cancelOrder(3, 0);
      _cancelOrder(4, 0);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 11);
    }

    // SubAccount#1
    {
      // Total
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 6);

      // Pagination
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 5);
      assertEq(_orders.length, 1);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 10);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(0, 1);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 5);

      _cancelOrder(3, 1);
      _cancelOrder(4, 1);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 3);
    }

    // SubAccount#2
    {
      // Pagination
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 2), 5, 0);
      assertEq(_orders.length, 1);

      // Cancellation
      _cancelOrder(0, 2);
      _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_getSubAccount(ALICE, 2), 100, 0);
      assertEq(_orders.length, 0);
    }
  }

  function testCorrectness_getMarketActiveOrdersBySubAccount() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;

    // SubAccount#0
    {
      // Total
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 9);

      // Pagination
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 5);
      assertEq(_orders.length, 4);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 10);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(2, 0);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 8);

      _cancelOrder(4, 0);
      _cancelOrder(5, 0);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 6);
    }

    // SubAccount#1
    {
      // Pagination
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 0);
      assertEq(_orders.length, 3);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 5);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(4, 1);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 2);

      _cancelOrder(5, 1);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 1);
    }

    // SubAccount#2
    {
      // Pagination
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 2), 5, 0);
      assertEq(_orders.length, 1);

      // Cancellation
      _cancelOrder(0, 2);
      _orders = limitTradeHandler.getMarketActiveOrdersBySubAccount(_getSubAccount(ALICE, 2), 100, 0);
      assertEq(_orders.length, 0);
    }
  }

  function testCorrectness_getLimitActiveOrdersBySubAccount() external {
    ILimitTradeHandler.LimitOrder[] memory _orders;

    // SubAccount#0
    {
      // Total
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 5);

      // Pagination
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 0);
      assertEq(_orders.length, 5);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 5, 5);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(0, 0);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 4);

      _cancelOrder(6, 0);
      _cancelOrder(7, 0);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 0), 100, 0);
      assertEq(_orders.length, 2);
    }

    // SubAccount#1
    {
      // Pagination
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 0);
      assertEq(_orders.length, 3);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 5, 5);
      assertEq(_orders.length, 0);

      // Cancellation
      _cancelOrder(1, 1);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 2);

      _cancelOrder(2, 1);
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 1), 100, 0);
      assertEq(_orders.length, 1);
    }

    // SubAccount#2
    {
      // Pagination
      _orders = limitTradeHandler.getLimitActiveOrdersBySubAccount(_getSubAccount(ALICE, 2), 5, 0);
      assertEq(_orders.length, 0);
    }
  }
}
