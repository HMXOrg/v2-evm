// SPDX-License-Identifier: MIT
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
    // 8 limit orders
    // 13 limit orders
    _createLimitOrder();
    _createLimitOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createLimitOrder();
    _createLimitOrder();
    _createMarketOrder();
    _createLimitOrder();
    _createLimitOrder();
    _createLimitOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createLimitOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
    _createMarketOrder();
  }

  function _createLimitOrder() internal {
    vm.prank(ALICE);
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
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

  function _createMarketOrder() internal {
    vm.prank(ALICE);
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
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

  function _cancelOrder(uint256 _orderIndex) internal {
    vm.prank(ALICE);
    limitTradeHandler.cancelOrder({ _subAccountId: 0, _orderIndex: _orderIndex });
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

      _cancelOrder(0);

      _orders = limitTradeHandler.getAllActiveOrders(100, 0);
      assertEq(_orders.length, 20);

      _cancelOrder(3);
      _cancelOrder(4);

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
      _cancelOrder(0);

      // should not change
      _orders = limitTradeHandler.getMarketActiveOrders(100, 0);
      assertEq(_orders.length, 13);

      // cancel order 3, 4 (both are market)
      _cancelOrder(3);
      _cancelOrder(4);

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
      _cancelOrder(0);

      _orders = limitTradeHandler.getLimitActiveOrders(100, 0);
      assertEq(_orders.length, 7);

      // cancel order 3, 4 (both are market)
      _cancelOrder(3);
      _cancelOrder(4);

      // should not change
      _orders = limitTradeHandler.getLimitActiveOrders(100, 0);
      assertEq(_orders.length, 7);
    }
  }
}
