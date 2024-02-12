// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LiquidityHandler02_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler02_Base.t.sol";
import { ILiquidityHandler02 } from "@hmx/handlers/interfaces/ILiquidityHandler02.sol";

contract LiquidityHandler02_Getter is LiquidityHandler02_Base {
  bytes32[] internal priceUpdateData;
  bytes32[] internal publishTimeUpdateData;

  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  function _createOrder() internal returns (uint256 _orderIndex) {
    vm.deal(ALICE, 5 ether);
    wbtc.mint(ALICE, 1 ether);

    vm.prank(ALICE);
    wbtc.approve(address(liquidityHandler), 1 ether);
    vm.prank(ALICE);
    _orderIndex = liquidityHandler.createAddLiquidityOrder{ value: 5 ether }(
      ALICE,
      SUB_ID,
      address(wbtc),
      1 ether,
      1 ether,
      5 ether,
      false
    );
  }

  function _executeOrder(uint256 orderIndex) internal {
    ILiquidityHandler02.ExecuteOrdersParam memory params;
    address[] memory accounts = new address[](1);
    uint8[] memory subAccountIds = new uint8[](1);
    uint256[] memory orderIndexes = new uint256[](1);
    accounts[0] = ALICE;
    subAccountIds[0] = SUB_ID;
    orderIndexes[0] = orderIndex;

    params.accounts = accounts;
    params.subAccountIds = subAccountIds;
    params.orderIndexes = orderIndexes;
    params.feeReceiver = payable(FEEVER);
    params.priceData = priceUpdateData;
    params.publishTimeData = publishTimeUpdateData;
    params.minPublishTime = block.timestamp;
    params.encodedVaas = keccak256("someEncodedVaas");
    params.isRevert = false;

    liquidityHandler.executeOrders(params);
  }

  function testCorrectness_getActiveLiquidityOrders02() external {
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 0);
    assertEq(liquidityHandler.getAllExecutedOrders(10, 0).length, 0);

    for (uint i = 0; i < 3; i++) {
      uint256 index = _createOrder();
      _executeOrder(index);
    }
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 0);
    assertEq(liquidityHandler.getAllExecutedOrders(10, 0).length, 3);

    for (uint i = 3; i < 14; i++) {
      uint256 index = _createOrder();
      _executeOrder(index);
    }
    assertEq(liquidityHandler.getAllExecutedOrders(20, 0).length, 14);

    assertEq(liquidityHandler.getAllActiveOrders(4, 0).length, 0);
    assertEq(liquidityHandler.getAllActiveOrders(4, 4).length, 0);
    assertEq(liquidityHandler.getAllActiveOrders(4, 8).length, 0);
  }

  function testCorrectness_getExecutedLiquidityOrders02() external {
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 0);
    assertEq(liquidityHandler.getAllExecutedOrders(10, 0).length, 0);

    for (uint i = 0; i < 3; i++) {
      _createOrder();
    }
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 3);
    for (uint i = 0; i < 3; i++) {
      _executeOrder(i);
    }
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 0);
    assertEq(liquidityHandler.getAllExecutedOrders(10, 0).length, 3);

    for (uint i = 3; i < 12; i++) {
      _createOrder();
    }
    assertEq(liquidityHandler.getAllActiveOrders(10, 0).length, 9);
    for (uint i = 3; i < 12; i++) {
      _executeOrder(i);
    }
    assertEq(liquidityHandler.getAllExecutedOrders(20, 0).length, 12);
    assertEq(liquidityHandler.getAllExecutedOrders(4, 0).length, 4);
    assertEq(liquidityHandler.getAllExecutedOrders(4, 4).length, 4);
    assertEq(liquidityHandler.getAllExecutedOrders(4, 8).length, 4);
    assertEq(liquidityHandler.getAllExecutedOrders(4, 11).length, 1);
  }

  function testCorrectness_getOrders_timestampCorrectness02() external {
    vm.warp(block.timestamp + 100);

    // Open 2 orders
    uint256 index1 = _createOrder(); // Intention: success
    uint256 index2 = _createOrder(); // Intention: fail

    // assert timestamp and status
    {
      ILiquidityHandler02.LiquidityOrder[] memory _orders = liquidityHandler.getAllActiveOrders(2, 0);

      assertEq(_orders[0].orderIndex, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 0);
      assertEq(uint(_orders[0].status), 0); // pending

      assertEq(_orders[1].orderIndex, 1);
      assertEq(_orders[1].createdTimestamp, 101);
      assertEq(_orders[1].executedTimestamp, 0);
      assertEq(uint(_orders[1].status), 0); // pending
    }

    vm.warp(block.timestamp + 100);

    // Execute
    _executeOrder(index1);
    mockLiquidityService.setReverted(true);
    _executeOrder(index2); // make the second order fail

    // assert timestamp and status
    {
      ILiquidityHandler02.LiquidityOrder[] memory _activeOrders = liquidityHandler.getAllActiveOrders(2, 0);
      ILiquidityHandler02.LiquidityOrder[] memory _orders = liquidityHandler.getAllExecutedOrders(2, 0);
      assertEq(_activeOrders.length, 0);
      assertEq(_orders.length, 1); // should have only 1 executed order, failed one will be removed.

      assertEq(_orders[0].orderIndex, 0);
      assertEq(_orders[0].createdTimestamp, 101);
      assertEq(_orders[0].executedTimestamp, 201);
      assertEq(uint(_orders[0].status), 1); // success
    }
  }
}
