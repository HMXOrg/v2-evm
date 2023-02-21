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

  /// @notice

  // test_correctness_refund Order
  // test_correctness_createRemoveLiquidity Order ()
  // test_revert_createRemoveLiquidity Order
  // test_revert_notOrderExecutor

  function test_correctness_executeOrder_IncreaseOneOrder() external {
    ILiquidityHandler.LiquidityOrder memory increaseOrder = ILiquidityHandler.LiquidityOrder({
      account: payable(address(this)),
      token: address(wbtc),
      amount: 1 ether,
      minOut: 1 ether,
      isAdd: true,
      shouldUnwrap: false
    });

    weth.mint(ALICE, 10 ether);
    wbtc.mint(ALICE, 1 ether);
    console.log("alice", address(ALICE));

    vm.startPrank(ALICE);

    wbtc.approve(address(liquidityHandler), type(uint256).max);

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(address(wbtc), 1 ether, 1 ether, 5 ether, false);

    assertEq(weth.balanceOf(address(liquidityHandler)), 5 ether, "Native Token Balance");

    console.log(wbtc.balanceOf(address(liquidityHandler)));
    assertEq(wbtc.balanceOf(address(liquidityHandler)), 0, "User Liquidity Balance");

    ILiquidityHandler.LiquidityOrder[] memory _orderResults = liquidityHandler.getLiquidityOrders(
      address(liquidityHandler)
    );
    assertEq(_orderResults.length, 1, "Order Amount After Created Order");
    vm.stopPrank();

    // ILiquidityHandler.LiquidityOrder[] memory orders = new ILiquidityHandler.LiquidityOrder[](1);
    // orders[0] = increaseOrder;

    // liquidityHandler.executeOrders(orders, new bytes[](0));
  }
}
