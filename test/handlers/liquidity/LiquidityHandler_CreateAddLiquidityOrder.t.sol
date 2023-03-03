// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { console } from "forge-std/console.sol";

// - revert
//   - Try notAcceptedToken
//   - Try _executionFee < minExecutionFee
//   - Try shoulWrap Error
//   - Try msg.value != minExecutionFee
//   - Try cancelOrder not owner
//   - Try cancelOrder with uncreated order

// - success
//   - Try executeOrder_createAddLiquidityOrder
//   - Try executeOrder_createAddLiquidityOrder_multiple

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

  function test_correctness_addLiquidityOrder() external {
    _createAddLiquidityOrder(0);

    assertEq(liquidityHandler.getLiquidityOrders(address(ALICE)).length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
  }

  function test_correctness_addLiquidityOrder_multiple() external {
    _createAddLiquidityOrder(0);
    _createAddLiquidityOrder(1);

    assertEq(liquidityHandler.getLiquidityOrders(address(ALICE)).length, 2, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 1, "Order Index After Executed Order");
  }

  function _createAddLiquidityOrder(uint256 _index) internal {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);

    vm.startPrank(ALICE);

    wbtc.approve(address(liquidityHandler), type(uint256).max);

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);

    // Assertion after createLiquidity
    // alice should has 0 wbtc (open order)
    // handler should has 1 order on alice
    assertEq(wbtc.balanceOf(ALICE), 0, "User Liquidity Balance");

    ILiquidityHandler.LiquidityOrder[] memory _beforeExecuteOrders = liquidityHandler.getLiquidityOrders(
      address(ALICE)
    );
    vm.stopPrank();

    assertEq(_beforeExecuteOrders.length, _index + 1, "Order Amount After Created Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), _index, "Order Index After Created Order");

    assertEq(_beforeExecuteOrders[_index].account, ALICE, "Alice Order.account");
    assertEq(_beforeExecuteOrders[_index].token, address(wbtc), "Alice Order.token");
    assertEq(_beforeExecuteOrders[_index].amount, 1 ether, "Alice Order.amount");
    assertEq(_beforeExecuteOrders[_index].minOut, 1 ether, "Alice Order.minOut");
    assertEq(_beforeExecuteOrders[_index].isAdd, true, "Alice Order.isAdd");
    assertEq(_beforeExecuteOrders[_index].shouldUnwrap, false, "Alice Order.shouldUnwrap");
  }
}
