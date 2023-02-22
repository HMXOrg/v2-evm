// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "../../../src/handlers/interfaces/ILiquidityHandler.sol";
import { console } from "../../../lib/forge-std/src/console.sol";

contract LiquidityHandler_ExecuteOrder is LiquidityHandler_Base {
  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  function _createIncreaseOrder() internal {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    weth.mint(ALICE, 10 ether);
    wbtc.mint(ALICE, 1 ether);
    console.log("alice", address(ALICE));

    vm.startPrank(ALICE);

    wbtc.approve(address(liquidityHandler), type(uint256).max);

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);

    // Assertion after createLiquidity
    // alice should has 0 wbtc (open order),  (5 weth left)
    // handler should has 1 order on alice
    assertEq(weth.balanceOf(address(liquidityHandler)), 5 ether, "Native Token Balance");
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

  function test_correctness_executeOrder_IncreaseOneOrder() external {
    _createIncreaseOrder();

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersBefore = liquidityHandler.getLiquidityOrders(address(ALICE));
    // Handler executor
    liquidityHandler.executeOrders(_aliceOrdersBefore, new bytes[](0));
    // Assertion after ExecuteOrder

    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));
    // array size should be the same but LastIndex should be 0
    assertEq(_aliceOrdersAfter.length, 1, "Order Amount After Executed Order");
    assertEq(liquidityHandler.lastOrderIndex(ALICE), 0, "Order Index After Executed Order");
  }

  function test_correctness_executeOrder_refundOrder() external {
    _createIncreaseOrder();
    ILiquidityHandler.LiquidityOrder[] memory aliceOrdersBefore = liquidityHandler.getLiquidityOrders(address(ALICE));

    liquidityHandler.cancelLiquidityOrder(aliceOrdersBefore);

    ILiquidityHandler.LiquidityOrder[] memory aliceOrdersAfter = liquidityHandler.getLiquidityOrders(address(ALICE));
    assertEq(aliceOrdersAfter.);
  }

  function test_correctness_executeOrder_createRemoveLiquidityOrder() external {}

  function test_correctness_cancelOrder() external {}

  function test_revert_createRemoveLiquidityOrder() external {}

  function test_revert_cancelOrder_notOrderExecutor() external {}

  function test_revert_executeOrder_notOrderExecutor() external {
    _createIncreaseOrder();
    ILiquidityHandler.LiquidityOrder[] memory _aliceOrdersBefore = liquidityHandler.getLiquidityOrders(address(ALICE));

    // Handler executor
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_NotWhitelisted()"));
    liquidityHandler.executeOrders(_aliceOrdersBefore, new bytes[](0));
  }
}
