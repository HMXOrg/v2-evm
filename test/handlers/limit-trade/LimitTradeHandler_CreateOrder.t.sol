// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "../../../src/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try creating an order will too low execution fee
//   - Try creating an order with incorrect `msg.value`
//   - Try creating an order with sub-account id > 255
// - success
//   - Try creating BUY and SELL orders and check that the indices of the orders are correct and that all orders are created correctly.

contract LimitTradeHandler_CreateOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  // Create order without transferring the native token as execution fee and supply 0 execution fee
  function testRevert_createOrder_InsufficientExecutionFee() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InsufficientExecutionFee()"));
    limitTradeHandler.createOrder({
      _subAccountId: 0,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0 ether,
      _reduceOnly: false
    });
  }

  // Create order without transferring the native token as execution fee
  function testRevert_createOrder_IncorrectValueTransfer() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_IncorrectValueTransfer()"));
    limitTradeHandler.createOrder({
      _subAccountId: 3,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });
  }

  // Create order with sub-account id > 255
  function testRevert_createOrder_BadSubAccountId() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_BadSubAccountId()"));
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 1000,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });
  }

  // Create BUY orders and check their validity
  function testCorrectness_createOrder_BuyOrder() external {
    uint256 balanceBefore = address(this).balance;

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

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
    assertEq(limitOrder.sizeDelta, 1000 * 1e30);
    assertEq(limitOrder.triggerPrice, 1000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, false);

    // // Open another Long order with the same sub account
    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _subAccountId: 0,
      _marketIndex: 2,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether,
      _reduceOnly: false
    });
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 2);
    assertEq(limitOrder.sizeDelta, 2000 * 1e30);
    assertEq(limitOrder.triggerPrice, 2000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.2 ether);
    assertEq(limitOrder.reduceOnly, false);

    // // Open another Long order with another sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 3,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 3000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 3);
    assertEq(limitOrder.sizeDelta, 3000 * 1e30);
    assertEq(limitOrder.triggerPrice, 3000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, false);

    // Open another Short order with 7th sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 4,
      _sizeDelta: 4000 * 1e30,
      _triggerPrice: 4000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: true
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      2,
      "limitOrdersIndex should increase by one."
    );
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 4);
    assertEq(limitOrder.sizeDelta, 4000 * 1e30);
    assertEq(limitOrder.triggerPrice, 4000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, true);
  }

  // Create SELL orders and check their validity
  function testCorrectness_createOrder_SellOrder() external {
    uint256 balanceBefore = address(this).balance;

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

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
    assertEq(limitOrder.sizeDelta, -1000 * 1e30);
    assertEq(limitOrder.triggerPrice, 1000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, false);

    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _subAccountId: 0,
      _marketIndex: 2,
      _sizeDelta: -2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether,
      _reduceOnly: false
    });
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 2);
    assertEq(limitOrder.sizeDelta, -2000 * 1e30);
    assertEq(limitOrder.triggerPrice, 2000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.2 ether);
    assertEq(limitOrder.reduceOnly, false);

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 3,
      _sizeDelta: -3000 * 1e30,
      _triggerPrice: 3000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: true
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );
    (
      limitOrder.account,
      limitOrder.triggerAboveThreshold,
      limitOrder.reduceOnly,
      limitOrder.sizeDelta,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.triggerPrice,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 3);
    assertEq(limitOrder.sizeDelta, -3000 * 1e30);
    assertEq(limitOrder.triggerPrice, 3000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);
    assertEq(limitOrder.reduceOnly, true);
  }
}
