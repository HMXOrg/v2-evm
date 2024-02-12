// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LiquidityHandler02_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler02_Base.t.sol";
import { ILiquidityHandler02 } from "@hmx/handlers/interfaces/ILiquidityHandler02.sol";

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

contract LiquidityHandler02_CreateRemoveLiquidityOrder is LiquidityHandler02_Base {
  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  /**
   * REVERT
   */
  function test_revert_notAcceptedToken02() external {
    vm.deal(ALICE, 5 ether);

    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedLiquidity()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(bad),
      1 ether,
      1 ether,
      5 ether,
      false
    );
  }

  function test_revert_InsufficientExecutionFee02() external {
    vm.deal(ALICE, 5 ether);
    hlp.mint(ALICE, 5 ether);
    vm.startPrank(ALICE);

    hlp.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler02_InsufficientExecutionFee()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      3 ether,
      false
    );
    vm.stopPrank();
  }

  function test_revert_incorrectValueTransfer02() external {
    vm.deal(ALICE, 5 ether);
    hlp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    hlp.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler02_InCorrectValueTransfer()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 3 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      5 ether,
      false
    );
    vm.stopPrank();
  }

  function test_revert_nativeIncorrectValueTransfer02() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);

    vm.startPrank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler02_InCorrectValueTransfer()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 3 ether }(
      ALICE,
      SUB_ID,
      address(weth),
      1 ether,
      1 ether,
      5 ether,
      false
    );
    vm.stopPrank();
  }

  function test_revert_hlpCircuitBreaker02() external {
    mockLiquidityService.setHlpEnabled(false);

    vm.deal(ALICE, 5 ether);
    hlp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    hlp.approve(address(liquidityHandler), type(uint256).max);

    // hlpIn 5 ether, execution fee 5
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      5 ether,
      0,
      5 ether,
      false
    );
    vm.stopPrank();
  }

  function test_revert_badAmount02() external {
    vm.deal(ALICE, 5 ether);
    hlp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    hlp.approve(address(liquidityHandler), type(uint256).max);

    // hlpIn 5 ether, execution fee 5
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(ALICE, SUB_ID, address(wbtc), 0, 0, 5 ether, false);
    vm.stopPrank();
  }

  /**
   * CORRECTNESS
   */

  function test_correctness_executeOrder_removeLiquidity02() external {
    _createRemoveLiquidityOrder();

    ILiquidityHandler02.LiquidityOrder[] memory _aliceOrders = liquidityHandler.getAllActiveOrders(10, 0);
    assertEq(_aliceOrders.length, 1, "Order Amount After Executed Order");
  }

  function test_correctness_executeOrder_removeLiquidity_multiple02() external {
    _createRemoveLiquidityOrder();
    _createRemoveLiquidityOrder();

    ILiquidityHandler02.LiquidityOrder[] memory _aliceOrders = liquidityHandler.getAllActiveOrders(10, 0);
    assertEq(_aliceOrders.length, 2, "Order Amount After Executed Order");
  }

  function _createRemoveLiquidityOrder() internal {
    vm.deal(ALICE, 5 ether);
    hlp.mint(ALICE, 5 ether);

    vm.startPrank(ALICE);
    hlp.approve(address(liquidityHandler), type(uint256).max);

    // hlpIn 5 ether, execution fee 5
    uint256 _index = liquidityHandler.createRemoveLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      5 ether,
      0,
      5 ether,
      false
    );
    vm.stopPrank();

    assertEq(hlp.balanceOf(ALICE), 0, "User HLP Balance");

    ILiquidityHandler02.LiquidityOrder[] memory _orders = liquidityHandler.getAllActiveOrders(10, 0);

    assertEq(_orders[_index].account, ALICE, "Alice Order.account");
    assertEq(_orders[_index].token, address(wbtc), "Alice Order.token");
    assertEq(_orders[_index].amount, 5 ether, "Alice HLP Order.amount");
    assertEq(_orders[_index].minOut, 0, "Alice WBTC Order.minOut");
    assertEq(_orders[_index].actualAmountOut, 0, "Alice WBTC Order.actualAmountOut");
    assertEq(_orders[_index].isAdd, false, "Alice Order.isAdd");
    assertEq(_orders[_index].isNativeOut, false, "Alice Order.isNativeOut");
  }
}
