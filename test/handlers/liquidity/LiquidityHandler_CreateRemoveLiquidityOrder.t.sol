// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { console } from "../../../lib/forge-std/src/console.sol";

// - revert
//   - Try notAcceptedToken
//   - Try _executionFee < minExecutionFee
//   - Try shouldWrap Error
//   - Try msg.value != minExecutionFee
//   - Try cancelOrder not owner
//   - Try cancelOrder with uncreated order

// - success
//   - Try executeOrder_createRemoveLiquidityOrder
//   - Try executeOrder_createRemoveLiquidityOrder_multiple

contract LiquidityHandler_CreateRemoveLiquidityOrder is LiquidityHandler_Base {
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

    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(address(bad), 1 ether, 1 ether, 5 ether, false);
  }

  function test_revert_InsufficientExecutionFee() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);

    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InsufficientExecutionFee()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 3 ether, false);
  }

  function test_revert_incorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 3 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);
  }

  function test_revert_nativeIncorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 3 ether }(address(weth), 1 ether, 1 ether, 5 ether, false);
  }

  /**
   * CORRECTNESS
   */

  function test_correctness_executeOrder_removeLiquidity() external {
    _createRemoveLiquidityOrder(0);

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));
    assertEq(_aliceOrders.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
  }

  function test_correctness_executeOrder_removeLiquidity_multiple() external {
    _createRemoveLiquidityOrder(0);
    _createRemoveLiquidityOrder(1);

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrders = liquidityHandler.getLiquidityOrders(address(ALICE));
    assertEq(_aliceOrders.length, 2, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 1, "Order Index After Executed Order");
  }

  function _createRemoveLiquidityOrder(uint256 _index) internal {
    vm.deal(ALICE, 5 ether);
    plp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    plp.approve(address(liquidityHandler), type(uint256).max);

    // plpIn 5 ether, execution fee 5
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
}
