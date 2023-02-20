// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "../../../src/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try creating an order will too low execution fee
//   - Try creating an order with incorrect `msg.value`
//   - Try creating an order with sub-account id > 255
//   - Try creating a DECREASE order with negative `_sizeDelta`
// - success
//   - Try creating INCREASE and DECREASE orders and check that the indices of the orders are correct and that all orders are created correctly.

contract LimitTradeHandler_CreateOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_createOrder_InsufficientExecutionFee() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InsufficientExecutionFee()"));
    limitTradeHandler.createOrder({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0 ether
    });
  }

  function testRevert_createOrder_IncorrectValueTransfer() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_IncorrectValueTransfer()"));
    limitTradeHandler.createOrder({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 3,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });
  }

  function testRevert_createOrder_BadSubAccountId() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_BadSubAccountId()"));
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 1000,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });
  }

  function testRevert_createOrder_WrongSizeDelta() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_WrongSizeDelta()"));
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.DECREASE,
      _subAccountId: 0,
      _marketIndex: 0,
      _sizeDelta: -100,
      _triggerPrice: 1000,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });
  }

  function testCorrectness_createOrder_IncreaseOrder() external {
    uint256 balanceBefore = address(this).balance;

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

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
    assertEq(limitOrder.sizeDelta, 1000 * 1e30);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 1000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);

    // Open another Long order with the same sub account
    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 0,
      _marketIndex: 2,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether
    });
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");
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
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 2);
    assertEq(limitOrder.sizeDelta, 2000 * 1e30);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 2000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.2 ether);

    // Open another Long order with another sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 7,
      _marketIndex: 3,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 3000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );
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
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 3);
    assertEq(limitOrder.sizeDelta, 3000 * 1e30);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 3000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);

    // Open another Short order with 7th sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.INCREASE,
      _subAccountId: 7,
      _marketIndex: 4,
      _sizeDelta: -4000 * 1e30,
      _triggerPrice: 4000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      2,
      "limitOrdersIndex should increase by one."
    );
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
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 4);
    assertEq(limitOrder.sizeDelta, -4000 * 1e30);
    assertEq(limitOrder.isLong, false);
    assertEq(limitOrder.triggerPrice, 4000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);
  }

  function testCorrectness_createOrder_DecreaseOrder() external {
    uint256 balanceBefore = address(this).balance;

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.DECREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

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
    assertEq(limitOrder.sizeDelta, 1000 * 1e30);
    assertEq(limitOrder.isLong, true, "isLong");
    assertEq(limitOrder.triggerPrice, 1000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.1 ether);

    // Open another Long order with the same sub account
    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 2,
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );
    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _orderType: ILimitTradeHandler.OrderType.DECREASE,
      _subAccountId: 0,
      _marketIndex: 2,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether
    });
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");
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
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 0);
    assertEq(limitOrder.marketIndex, 2);
    assertEq(limitOrder.sizeDelta, 2000 * 1e30);
    assertEq(limitOrder.isLong, true);
    assertEq(limitOrder.triggerPrice, 2000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, true);
    assertEq(limitOrder.executionFee, 0.2 ether);

    // Open another Short order with another sub account
    mockPerpStorage.setPositionBySubAccount(
      _getSubAccount(address(this), 7),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 7,
        marketIndex: 3,
        positionSizeE30: -100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: ILimitTradeHandler.OrderType.DECREASE,
      _subAccountId: 7,
      _marketIndex: 3,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 3000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );
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
    ) = limitTradeHandler.limitOrders(_getSubAccount(address(this), 7), 0);
    assertEq(limitOrder.account, address(this));
    assertEq(limitOrder.subAccountId, 7);
    assertEq(limitOrder.marketIndex, 3);
    assertEq(limitOrder.sizeDelta, 3000 * 1e30);
    assertEq(limitOrder.isLong, false);
    assertEq(limitOrder.triggerPrice, 3000 * 1e30);
    assertEq(limitOrder.triggerAboveThreshold, false);
    assertEq(limitOrder.executionFee, 0.1 ether);
  }
}
