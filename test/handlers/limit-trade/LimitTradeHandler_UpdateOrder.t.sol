// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "../../../src/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try updating a non existent order
// - success
//   - Try updating an order and check that it is updated correctly

contract LimitTradeHandler_UpdateOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  // Update a non-existent order
  function testRevert_update_NonExistentOrder() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.updateOrder({
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _reduceOnly: false
    });
  }

  // Update an order
  function testCorrectness_updateOrder() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });

    ILimitTradeHandler.LimitOrder memory limitOrder;
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 1);
    assertEq(limitOrder.sizeDelta, 100);
    assertEq(limitOrder.triggerPrice, 1000);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, false);

    limitTradeHandler.updateOrder({
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 200,
      _triggerPrice: 2000,
      _triggerAboveThreshold: true,
      _reduceOnly: false
    });

    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 1);
    assertEq(limitOrder.sizeDelta, 200);
    assertEq(limitOrder.triggerPrice, 2000);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, false);
  }
}
