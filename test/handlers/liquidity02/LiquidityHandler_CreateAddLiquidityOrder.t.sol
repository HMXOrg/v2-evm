// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LiquidityHandler_Base02, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base02.t.sol";
import { ILiquidityHandler02 } from "@hmx/handlers/interfaces/ILiquidityHandler02.sol";

// - revert
//   - Try notAcceptedToken
//   - Try _executionFee < minExecutionFee
//   - Try shouldWrap Error
//   - Try msg.value != minExecutionFee
//   - Try cancelOrder not owner
//   - Try cancelOrder with uncreated order
//   - Try addLiquidity BadAmount
//   - Try addLiquidity CircuitBreaker

// - success
//   - Try executeOrder_createAddLiquidityOrder
//   - Try executeOrder_createAddLiquidityOrder_multiple

contract LiquidityHandler_CreateAddLiquidityOrder is LiquidityHandler_Base02 {
  uint8 internal constant SUB_ID = 0;

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

    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(bad),
      1 ether,
      1 ether,
      5 ether,
      false
    );
  }

  function test_revert_InsufficientExecutionFee() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);

    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InsufficientExecutionFee()"));
    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      3 ether,
      false
    );
  }

  function test_revert_incorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createAddLiquidityOrder{ value: 3 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      5 ether,
      false
    );
  }

  function test_revert_nativeIncorrectValueTransfer() external {
    wbtc.mint(ALICE, 1 ether);
    vm.deal(ALICE, 5 ether);
    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.expectRevert(abi.encodeWithSignature("ILiquidityHandler_InCorrectValueTransfer()"));
    liquidityHandler.createAddLiquidityOrder{ value: 3 ether }(
      ALICE,
      SUB_ID,
      address(weth),
      1 ether,
      1 ether,
      5 ether,
      false
    );
  }

  function test_revert_hlpCircuitBreaker() external {
    mockLiquidityService.setHlpEnabled(false);

    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);

    vm.startPrank(ALICE);
    wbtc.approve(address(liquidityHandler), type(uint256).max);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(
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

  function test_revert_badAmount() external {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);

    vm.startPrank(ALICE);
    wbtc.approve(address(liquidityHandler), type(uint256).max);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(ALICE, SUB_ID, address(wbtc), 0, 0, 5 ether, false);
    vm.stopPrank();
  }

  /**
   * CORRECTNESS
   */

  function test_correctness_addLiquidityOrder() external {
    _createAddLiquidityOrder();

    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 1, "Order Amount After Executed Order");
  }

  function test_correctness_addLiquidityOrder_multiple() external {
    _createAddLiquidityOrder();
    _createAddLiquidityOrder();

    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 2, "Order Amount After Executed Order");
  }

  function _createAddLiquidityOrder() internal {
    vm.deal(ALICE, 5 ether); //deal with out of gas
    wbtc.mint(ALICE, 1 ether);

    vm.startPrank(ALICE);

    wbtc.approve(address(liquidityHandler), type(uint256).max);

    uint256 _latestOrderIndex = liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      5 ether,
      false
    );

    // Assertion after createLiquidity
    // alice should has 0 wbtc (open order)
    // handler should has 1 order on alice
    assertEq(wbtc.balanceOf(ALICE), 0, "User Liquidity Balance");

    ILiquidityHandler02.LiquidityOrder[] memory _beforeExecuteOrders = liquidityHandler.getAllActiveOrders(10, 0);
    vm.stopPrank();

    assertEq(_beforeExecuteOrders[_latestOrderIndex].account, ALICE, "Alice Order.account");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].token, address(wbtc), "Alice Order.token");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].amount, 1 ether, "Alice Order.amount");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].minOut, 1 ether, "Alice Order.minOut");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].actualAmountOut, 0, "Alice Order.actualAmountOut");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].isAdd, true, "Alice Order.isAdd");
    assertEq(_beforeExecuteOrders[_latestOrderIndex].isNativeOut, false, "Alice Order.isNativeOut");
  }
}
