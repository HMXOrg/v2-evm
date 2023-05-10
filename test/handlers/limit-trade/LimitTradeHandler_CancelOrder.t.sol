// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try canceling a non existent order
// - success
//   - Try cancel an order, check that the order is cancelled and check if user is refunded with the execution fee

contract LimitTradeHandler_CancelOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();
  }

  // Cancel a non existent order
  function testRevert_cancel_NonExistentOrder() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.cancelOrder({ _subAccountId: 0, _orderIndex: 0 });
  }

  // Cancel an existing order
  function testCorrectness_cancelOrder() external {
    vm.deal(ALICE, 1 ether);
    uint256 balanceBefore = ALICE.balance;
    vm.startPrank(ALICE);
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _acceptablePrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , , , ) = limitTradeHandler.limitOrders(ALICE, 0);
    assertEq(limitOrder.account, ALICE);

    limitTradeHandler.cancelOrder({ _subAccountId: 0, _orderIndex: 0 });

    (limitOrder.account, , , , , , , , , , ) = limitTradeHandler.limitOrders(ALICE, 0);
    assertEq(limitOrder.account, address(0));

    uint256 balanceDiff = ALICE.balance - balanceBefore;
    assertEq(balanceDiff, 0 ether, "User should receive execution fee refund.");
  }
}
