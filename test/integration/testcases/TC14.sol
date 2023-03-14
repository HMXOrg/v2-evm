// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

// TC14 - TC15 will include in this case
contract TC14 is BaseIntTest_WithActions {
  function testCorrectness_CircuitBreaker() external {
    // T0: Initialized state
    // set circuit breaker
    configStorage.setLiquidityEnabled(false);

    // ALICE NEED 10k in terms of WBTC = 10000 /20000 * 10**8  = 5e7
    uint256 _amount = 5e7;

    // mint 0.5 btc and give 0.0001 gas
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, _amount);

    //T1 Alice Create Order Add Liquidity
    uint256 _orderIndex = _addLiquidityOnly(ALICE, ERC20(address(wbtc)), _amount, executionOrderFee);

    // Validate After CREATED Order
    ILiquidityHandler.LiquidityOrder[] memory _orders = liquidityHandler.getLiquidityOrders();
    assertEq(wbtc.balanceOf(ALICE), 0, "Alice Balance After Created Order");

    assertEq(_orders.length, 1, "Order Alice");
    assertEq(liquidityHandler.nextExecutionOrderIndex(), 0, "Order Index After Created Order");
    assertEq(FEEVER.balance, 0, "Feever Balance After Created Order");

    assertEq(weth.balanceOf(address(liquidityHandler)), executionOrderFee, "Balance WETH on Handler");

    assertEq(_orders[_orderIndex].account, ALICE, "Alice Order.account");
    assertEq(_orders[_orderIndex].token, address(wbtc), "Alice Order.token");
    assertEq(_orders[_orderIndex].amount, 5e7, "Alice Order.amount");
    assertEq(_orders[_orderIndex].minOut, 0, "Alice Order.minOut");
    assertEq(_orders[_orderIndex].isAdd, true, "Alice Order.isAdd");
    assertEq(_orders[_orderIndex].isNativeOut, false, "Alice Order.isNativeOut");

    // T2 Execute Order
    vm.prank(ORDER_EXECUTOR);
    liquidityHandler.executeOrder(_orderIndex, payable(FEEVER), initialPriceFeedDatas);

    _orders = liquidityHandler.getLiquidityOrders();
    // Validate After EXECUTED Order
    assertEq(wbtc.balanceOf(ALICE), _amount, "Token Balance After Executed Order");
    assertEq(FEEVER.balance, executionOrderFee - initialPriceFeedDatas.length, "Feever Balance After Executed Order");
    assertEq(weth.balanceOf(address(liquidityHandler)), 0, " Balance WETH on Handler After Executed Order");
    assertEq(liquidityHandler.nextExecutionOrderIndex(), 1, "Order Index After Executed Order");
    assertEq(_orders[_orderIndex].amount, 0, "Alice Order should be delete After Executed Order");
  }

  function _addLiquidityOnly(
    address _liquidityProvider,
    ERC20 _tokenIn,
    uint256 _amountIn,
    uint256 _executionFee
  ) internal returns (uint256 _orderIndex) {
    vm.startPrank(_liquidityProvider);
    _tokenIn.approve(address(liquidityHandler), _amountIn);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    _orderIndex = liquidityHandler.createAddLiquidityOrder{ value: _executionFee }(
      address(_tokenIn),
      _amountIn,
      0,
      _executionFee,
      false
    );
    vm.stopPrank();

    return _orderIndex;
  }
}
