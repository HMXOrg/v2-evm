// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract TC01 is BaseIntTest_WithActions {
  function testCorrectness_AddAndRemoveLiquiditySuccess() external {
    // T0: Initialized state
    uint256 _totalExecutionOrderFee = executionOrderFee - initialPriceFeedDatas.length;
    // WBTC = 20k
    // ALICE NEED 10k in terms of WBTC = 10000 /20000 * 10**8  = 5e7
    uint256 _amount = 5e7;

    // mint 0.5 btc and give 0.0001 gas
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, _amount);

    // Alice Create Order And Executor Execute Order

    // T1: As a Liquidity, Alice adds 10,000 USD(GLP)
    addLiquidity(ALICE, ERC20(address(wbtc)), _amount, executionOrderFee, initialPriceFeedDatas);

    liquidityTester.assertLiquidityInfo(
      LiquidityTester.LiquidityExpectedData({
        token: address(wbtc),
        who: ALICE,
        lpTotalSupply: 99_70 ether,
        totalAmount: _amount,
        plpLiquidity: 49_850_000,
        plpAmount: 9_970 ether, //
        fee: 150_000, //fee = 0.5e8( 0.5e8 -0.3%) = 0.0015 * 1e8
        executionFee: _totalExecutionOrderFee
      })
    );

    // no one in PLP pool, so aum must be = totalSupply
    assertEq(calculator.getAUM(false, 0, 0), plpV2.totalSupply(), "AUM & total Supply mismatch");

    // T2: Alice withdraws 100,000 USD with PLP
    vm.deal(ALICE, executionOrderFee);

    uint256 amountToRemove = 100_000 ether;
    vm.startPrank(ALICE);

    plpV2.approve(address(liquidityHandler), amountToRemove);
    vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
    liquidityHandler.createRemoveLiquidityOrder{ value: executionOrderFee }(
      address(wbtc),
      amountToRemove,
      0,
      executionOrderFee,
      false
    );
    vm.stopPrank();

    // T3: Alice withdraws PLP 100 USD
    //  10000 -> 0.5 e8
    //   100 -> 0.005 e8 btc
    removeLiquidity(ALICE, address(wbtc), 100 ether, executionOrderFee, initialPriceFeedDatas);

    _totalExecutionOrderFee += (executionOrderFee - initialPriceFeedDatas.length);

    // PLP LIQUIDITY BEFORE =
    liquidityTester.assertLiquidityInfo(
      LiquidityTester.LiquidityExpectedData({
        token: address(wbtc),
        who: ALICE,
        lpTotalSupply: 98_70 ether, // 9970 plp - 100 plp
        totalAmount: 49_501_400, //(0.5 e8 - 0.005)+ 1400 fee
        plpLiquidity: 49_350_000, // 49_850_000 - 500_000
        plpAmount: 9_870 ether, //user plp
        //fee Alice addLiquidity (150_000) + fee Alice removeLiquidity(100 plp => 500_000-(500_000-0.28%) => 1,400 ) = 151400
        fee: 151_400,
        executionFee: _totalExecutionOrderFee
      })
    );

    // T5: As a Liquidity, Bob adds 100 USD(GLP)

    vm.deal(BOB, executionOrderFee);
    wbtc.mint(BOB, 500_000);

    vm.startPrank(BOB);
    wbtc.approve(address(liquidityHandler), 500_000);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    liquidityHandler.createAddLiquidityOrder{ value: executionOrderFee }(
      address(wbtc),
      500_000,
      0,
      executionOrderFee,
      false
    );
    vm.stopPrank();

    ILiquidityHandler.LiquidityOrder[] memory orders = liquidityHandler.getLiquidityOrders();

    vm.prank(ORDER_EXECUTOR);
    vm.expectRevert(abi.encodeWithSignature("ICalculator_PoolImbalance()"));

    liquidityHandler.executeOrder(orders.length - 1, payable(FEEVER), initialPriceFeedDatas);

    // T6: Alice max withdraws 9,900 USD PLP in pools
    vm.deal(ALICE, executionOrderFee);
    _totalExecutionOrderFee += (executionOrderFee - initialPriceFeedDatas.length);

    removeLiquidity(ALICE, address(wbtc), 9_870 ether, executionOrderFee, initialPriceFeedDatas);
    liquidityTester.assertLiquidityInfo(
      LiquidityTester.LiquidityExpectedData({
        token: address(wbtc),
        who: ALICE,
        lpTotalSupply: 0 ether,
        totalAmount: 299_450,
        plpLiquidity: 0,
        plpAmount: 0 ether,
        fee: 299_450,
        executionFee: _totalExecutionOrderFee
      })
    );
  }
}
