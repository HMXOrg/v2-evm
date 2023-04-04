// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { LimitOrderTester } from "../../testers/LimitOrderTester.sol";

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
      _triggerPrice: 2e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _executionFee: 0 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });
  }

  // Create order without transferring the native token as execution fee
  function testRevert_createOrder_IncorrectValueTransfer() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_IncorrectValueTransfer()"));
    limitTradeHandler.createOrder({
      _subAccountId: 3,
      _marketIndex: 0,
      _sizeDelta: 100,
      _triggerPrice: 2e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });
  }

  // Create BUY orders and check their validity
  function testCorrectness_createOrder_BuyOrder() external {
    uint256 balanceBefore = address(this).balance;

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 0,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _acceptablePrice: 2e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: 1000 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 1000 * 1e30,
        executionFee: 0.1 ether
      })
    });

    // Open another Long order with the same sub account
    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _acceptablePrice: 2000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether,
      _reduceOnly: false,
      _tpToken: address(0)
    });

    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(0),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: 2000 * 1e30,
        subAccountId: 0,
        marketIndex: 1,
        triggerPrice: 2000 * 1e30,
        acceptablePrice: 2000 * 1e30,
        executionFee: 0.2 ether
      })
    });

    // Open another Long order with another sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 1,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 0.3 * 1e30,
      _acceptablePrice: 0.3 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(wbtc)
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );

    limitOrderTester.assertLimitOrder({
      _subAccount: _getSubAccount(address(this), 7),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(wbtc),
        triggerAboveThreshold: false,
        reduceOnly: false,
        sizeDelta: 3000 * 1e30,
        subAccountId: 7,
        marketIndex: 1,
        triggerPrice: 0.3 * 1e30,
        acceptablePrice: 0.3 * 1e30,
        executionFee: 0.1 ether
      })
    });

    // Open another Short order with 7th sub account
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 1,
      _sizeDelta: 4000 * 1e30,
      _triggerPrice: 0.4 * 1e30,
      _acceptablePrice: 0.4 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      2,
      "limitOrdersIndex should increase by one."
    );

    limitOrderTester.assertLimitOrder({
      _subAccount: _getSubAccount(address(this), 7),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: false,
        reduceOnly: true,
        sizeDelta: 4000 * 1e30,
        subAccountId: 7,
        marketIndex: 1,
        triggerPrice: 0.4 * 1e30,
        acceptablePrice: 0.4 * 1e30,
        executionFee: 0.1 ether
      })
    });
  }

  // Create SELL orders and check their validity
  function testCorrectness_createOrder_SellOrder() external {
    uint256 balanceBefore = address(this).balance;

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 0,
      _sizeDelta: -1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _acceptablePrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(0)
    });

    uint256 balanceDiff = balanceBefore - address(this).balance;
    assertEq(balanceDiff, 0.1 ether, "Execution fee is correctly collected from user.");
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 1, "limitOrdersIndex should increase by one.");

    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(0),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: -1000 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 1000 * 1e30,
        executionFee: 0.1 ether
      })
    });

    limitTradeHandler.createOrder{ value: 0.2 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -2000 * 1e30,
      _triggerPrice: 2000 * 1e30,
      _acceptablePrice: 2005 * 1e30, // 2000 * (1.0025) = 2005
      _triggerAboveThreshold: true,
      _executionFee: 0.2 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });
    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 2, "limitOrdersIndex should increase by one.");

    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: false,
        sizeDelta: -2000 * 1e30,
        subAccountId: 0,
        marketIndex: 1,
        triggerPrice: 2000 * 1e30,
        acceptablePrice: 2000 * 1e30,
        executionFee: 0.2 ether
      })
    });

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 7,
      _marketIndex: 1,
      _sizeDelta: -3000 * 1e30,
      _triggerPrice: 0.3 * 1e30,
      _acceptablePrice: 0.3 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });
    assertEq(
      limitTradeHandler.limitOrdersIndex(_getSubAccount(address(this), 7)),
      1,
      "limitOrdersIndex should increase by one."
    );

    limitOrderTester.assertLimitOrder({
      _subAccount: _getSubAccount(address(this), 7),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: false,
        reduceOnly: true,
        sizeDelta: -3000 * 1e30,
        subAccountId: 7,
        marketIndex: 1,
        triggerPrice: 0.3 * 1e30,
        acceptablePrice: 0.3 * 1e30,
        executionFee: 0.1 ether
      })
    });
  }
}
