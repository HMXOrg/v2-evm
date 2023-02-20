// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "../../../src/handlers/interfaces/ILimitTradeHandler.sol";

contract LimitTradeHandler_UpdateOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_update_NonExistentOrder() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.updateOrder({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true
    });
  }

  function testCorrectness_updateOrder() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    ILimitTradeHandler.LimitOrder memory limitOrder;
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 1);
    assertEq(limitOrder.sizeDelta, 100);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 1000);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);

    limitTradeHandler.updateOrder({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 200,
      _triggerPrice: 2000,
      _triggerAboveThreshold: true
    });

    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 1);
    assertEq(limitOrder.sizeDelta, 200);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 2000);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);
  }
}
