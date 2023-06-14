// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { LimitOrderTester } from "../../testers/LimitOrderTester.sol";

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
      _mainAccount: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 2e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _reduceOnly: false,
      _tpToken: address(0)
    });
  }

  function testRevert_WhenUpdateMarketOrder() external {
    // create a market order (trigger price = 0)
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _mainAccount: address(this),
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

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_MarketOrderNoUpdate()"));
    limitTradeHandler.updateOrder({
      _mainAccount: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 2e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _reduceOnly: false,
      _tpToken: address(0)
    });
  }

  function testRevert_WhenConvertLimitOrderToMarketOrder() external {
    // create a limit order (trigger price > 0)
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _mainAccount: address(this),
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

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_LimitOrderConvertToMarketOrder()"));
    limitTradeHandler.updateOrder({
      _mainAccount: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 0,
      _acceptablePrice: 0,
      _triggerAboveThreshold: true,
      _reduceOnly: false,
      _tpToken: address(0)
    });
  }

  // Update an order
  function testCorrectness_updateOrder() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _mainAccount: address(this),
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

    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: 100,
        subAccountId: 0,
        marketIndex: 1,
        triggerPrice: 2e30,
        acceptablePrice: 2e30,
        executionFee: 0.1 ether
      })
    });

    limitTradeHandler.updateOrder({
      _mainAccount: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _sizeDelta: 200,
      _triggerPrice: 3e30,
      _acceptablePrice: 1e30,
      _triggerAboveThreshold: true,
      _reduceOnly: false,
      _tpToken: address(0)
    });

    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(0),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: 200,
        subAccountId: 0,
        marketIndex: 1,
        triggerPrice: 3e30,
        acceptablePrice: 1e30,
        executionFee: 0.1 ether
      })
    });
  }
}
