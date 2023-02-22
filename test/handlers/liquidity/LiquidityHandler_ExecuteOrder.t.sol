// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "../../../src/handlers/interfaces/ILiquidityHandler.sol";

// // - revert
// //   - Try directCall executeLiquidity
// //   - Try directCall refund
// //   - Try executeOrder not orderExecutor
// //   - Try cancelOrder not owner
// //   - Try cancelOrder with uncreated order

// // - success
// //   - Try executeOrder_addLiquidityOrder
// //   - Try executeOrder_removeLiquidityOrder
// //   - Try executeOrder_cancelOrder
// //   - Try executeOrder_refundOrder

contract LiquidityHandler_ExecuteOrder is LiquidityHandler_Base {
  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  /**
   * REVERT
   */
  function test_revert_directCall_executeLiquidity() external {
    _createAddLiquidityOrder();
    ILiquidityHandler.LiquidityOrder[] memory aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_NotExecutionState()"));
    liquidityHandler.executeLiquidity(aliceOrders[0]);
  }

  function test_revert_directCall_refund() external {
    _createAddLiquidityOrder();

    ILiquidityHandler.LiquidityOrder[] memory aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));

    // trying to directcall refund
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_NotRefundState()"));
    liquidityHandler.refund(aliceOrders[0]);
  }

  function test_revert_executeOrder_notOrderExecutor() external {
    _createAddLiquidityOrder();

    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_NotWhitelisted()"));
    liquidityHandler.executeOrder(ALICE, 0, new bytes[](0));
  }

  function test_revert_cancelOrder_notOwner() external {
    _createAddLiquidityOrder();

    vm.prank(ALICE);
    liquidityHandler.cancelLiquidityOrder(0);

    ILiquidityHandler.LiquidityOrder[] memory aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));
    assertEq(aliceOrders[0].account, address(0), "Alice account address");
  }

  function test_revert_cancelOrder_uncreatedOrder() external {
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_NoOrder()"));
    liquidityHandler.cancelLiquidityOrder(0);
  }

  /**
   * CORRECTNESS
   */

  function test_correctness_executeOrder_IncreaseOneOrder() external {
    _createAddLiquidityOrder();

    // Handler executor
    liquidityHandler.executeOrder(ALICE, 0, new bytes[](0));
    // Assertion after ExecuteOrder

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_aliceOrdersAfter.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
  }

  /// @dev plp burn and receive tokenOut in service
  function test_correctness_executeOrder_createRemoveLiquidityOrder() external {
    _createRemoveLiquidityOrder(0);

    // Handler executor
    liquidityHandler.executeOrder(ALICE, 0, new bytes[](0));
    // Assertion after ExecuteOrder
    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_aliceOrdersAfter.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
    assertEq(wbtc.balanceOf(ALICE), 5 ether, "ALICE received balance");
  }

  function test_correctness_executeOrder_createRemoveLiquidityOrders() external {
    _createRemoveLiquidityOrder(0);
    _createRemoveLiquidityOrder(1);

    // Handler executor
    liquidityHandler.executeOrder(ALICE, 0, new bytes[](0));
    liquidityHandler.executeOrder(ALICE, 1, new bytes[](0));
    // Assertion after ExecuteOrder

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_aliceOrdersAfter.length, 2, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 1, "Order Index After Executed Order");
    assertEq(wbtc.balanceOf(ALICE), 10 ether, "ALICE received balance");
  }

  /// @dev plp burn and receive tokenOut in service
  function test_correctness_executeOrder_native_createRemoveLiquidityOrder() external {
    _createRemoveLiquidityNativeOrder();

    // Handler executor
    liquidityHandler.executeOrder(ALICE, 0, new bytes[](0));
    // Assertion after ExecuteOrder

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_aliceOrdersAfter.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
    assertEq(ALICE.balance, 5 ether, "ALICE received balance");
  }

  function test_correctness_executeOrder_refundOrder() external {
    _createAddLiquidityOrder();
  }

  function test_correctness_cancelOrder() external {
    _createAddLiquidityOrder();

    vm.prank(ALICE);
    liquidityHandler.cancelLiquidityOrder(0);

    ILiquidityHandler.LiquidityOrder[] memory aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));
    assertEq(aliceOrders[0].account, address(0), "Alice account address");
  }

  function _createAddLiquidityOrder() internal {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);

    vm.startPrank(ALICE);

    wbtc.approve(address(liquidityHandler), type(uint256).max);

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);

    // Assertion after createLiquidity
    // alice should has 0 wbtc (open order),  (5 weth left)
    // handler should has 1 order on alice
    assertEq(wbtc.balanceOf(ALICE), 0, "User Liquidity Balance");

    ILiquidityHandler.LiquidityOrder[] memory _beforeExecuteOrders = liquidityHandler.getLiquidityOrders(
      address(ALICE)
    );
    vm.stopPrank();

    assertEq(_beforeExecuteOrders.length, 1, "Order Amount After Created Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Created Order");

    assertEq(_beforeExecuteOrders[0].account, ALICE, "Alice Order.account");
    assertEq(_beforeExecuteOrders[0].token, address(wbtc), "Alice Order.token");
    assertEq(_beforeExecuteOrders[0].amount, 1 ether, "Alice Order.amount");
    assertEq(_beforeExecuteOrders[0].minOut, 1 ether, "Alice Order.minOut");
    assertEq(_beforeExecuteOrders[0].isAdd, true, "Alice Order.isAdd");
    assertEq(_beforeExecuteOrders[0].shouldUnwrap, false, "Alice Order.shouldUnwrap");
  }

  function _createRemoveLiquidityOrder(uint256 _index) internal {
    vm.deal(ALICE, 5 ether);
    plp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    plp.approve(address(liquidityHandler), type(uint256).max);

    // plpIn 5 ether, executionfee 5
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(address(wbtc), 5 ether, 0, 5 ether, false);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 0, "User PLP Balance");

    ILiquidityHandler.LiquidityOrder[] memory _orders = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_orders[_index].account, ALICE, "Alice Order.account");
    assertEq(_orders[_index].token, address(wbtc), "Alice Order.token");
    assertEq(_orders[_index].amount, 5 ether, "Alice PLP Order.amount");
    assertEq(_orders[_index].minOut, 0, "Alice WBTC Order.minOut");
    assertEq(_orders[_index].isAdd, false, "Alice Order.isAdd");
    assertEq(_orders[_index].shouldUnwrap, false, "Alice Order.shouldUnwrap");
  }

  function _createRemoveLiquidityNativeOrder() internal {
    vm.deal(ALICE, 5 ether);
    plp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    plp.approve(address(liquidityHandler), type(uint256).max);

    // plpIn 5 ether, executionfee 5
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(address(weth), 5 ether, 0, 5 ether, true);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 0, "User PLP Balance");

    ILiquidityHandler.LiquidityOrder[] memory _orders = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_orders[0].account, ALICE, "Alice Order.account");
    assertEq(_orders[0].token, address(weth), "Alice Order.token");
    assertEq(_orders[0].amount, 5 ether, "Alice PLP Order.amount");
    assertEq(_orders[0].minOut, 0, "Alice WBTC Order.minOut");
    assertEq(_orders[0].isAdd, false, "Alice Order.isAdd");
    assertEq(_orders[0].shouldUnwrap, true, "Alice Order.shouldUnwrap");
  }
}
