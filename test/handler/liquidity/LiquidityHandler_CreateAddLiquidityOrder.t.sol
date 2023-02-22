// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "../../../src/handlers/interfaces/ILiquidityHandler.sol";
import { console } from "../../../lib/forge-std/src/console.sol";

// // - revert
// //   - Try notAcceptedToken
// //   - Try _executionFee < minExecutionFee
// //   - Try shoulWrap Error
// //   - Try msg.value != minExecutionFee
// //   - Try cancelOrder not owner
// //   - Try cancelOrder with uncreated order

// // - success
// //   - Try executeOrder_createAddLiquidityOrder

contract LiquidityHandler_CreateAddLiquidityOrder is LiquidityHandler_Base {
  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  /**
   * REVERT
   */
  function test_revert_notAcceptedToken() external {
    vm.deal(ALICE, 5 ether);

    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedLiquidity()"));

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(bad), 1 ether, 1 ether, 5 ether, false);
  }

  function test_revert_InsufficientExecutionFee() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);

    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InsufficientExecutionFee()"));
    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 3 ether, false);
  }

  function test_revert_incorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createAddLiquidityOrder{ value: 3 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);
  }

  function test_revert_nativeIncorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createAddLiquidityOrder{ value: 3 ether }(address(weth), 1 ether, 1 ether, 5 ether, false);
  }

  /**
   * CORRECTNESS
   */

  function test_correctness_executeOrder_IncreaseOrder() external {
    _createAddLiquidityOrder();

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersBefore = liquidityHandler.getLiquidityOrders(address(ALICE));
    // Handler executor
    liquidityHandler.executeOrders(_aliceOrdersBefore, new bytes[](0));
    // Assertion after ExecuteOrder

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));

    assertEq(_aliceOrdersAfter.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 1, "Order Index After Executed Order");
  }

  function _createAddLiquidityOrder() internal {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);
    console.log("alice", address(ALICE));

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
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 1, "Order Index After Created Order");

    assertEq(_beforeExecuteOrders[0].account, ALICE, "Alice Order.account");
    assertEq(_beforeExecuteOrders[0].token, address(wbtc), "Alice Order.token");
    assertEq(_beforeExecuteOrders[0].amount, 1 ether, "Alice Order.amount");
    assertEq(_beforeExecuteOrders[0].minOut, 1 ether, "Alice Order.minOut");
    assertEq(_beforeExecuteOrders[0].isAdd, true, "Alice Order.isAdd");
    assertEq(_beforeExecuteOrders[0].shouldUnwrap, false, "Alice Order.shouldUnwrap");
  }
}
