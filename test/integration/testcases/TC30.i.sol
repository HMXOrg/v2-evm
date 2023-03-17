// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract TC30 is BaseIntTest_WithActions {
  function test_correctness_executeMultipleOrders() external {
    // T0: Initialized state
    uint256 _totalExecutionOrderFee = executionOrderFee - initialPriceFeedDatas.length;

    vm.deal(ALICE, executionOrderFee);
    uint256 _aliceBTCAmount = 1e8;
    wbtc.mint(ALICE, _aliceBTCAmount);

    // Alice Create Order
    addLiquidity(ALICE, ERC20(address(wbtc)), _aliceBTCAmount, executionOrderFee, initialPriceFeedDatas, false);

    vm.deal(ALICE, executionOrderFee);
    uint256 _aliceUSDCAmount = 20_000 * 1e6;
    usdc.mint(ALICE, _aliceUSDCAmount);
    addLiquidity(ALICE, ERC20(address(usdc)), _aliceUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);

    uint256 _bobUSDCAmount = 1_000 * 1e6;
    vm.deal(BOB, executionOrderFee);
    usdc.mint(BOB, _bobUSDCAmount);
    addLiquidity(BOB, ERC20(address(usdc)), _bobUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);

    vm.deal(BOB, executionOrderFee);
    uint256 _bobBTCAmount = 0.5 * 1e8;
    wbtc.mint(BOB, _bobBTCAmount);
    addLiquidity(BOB, ERC20(address(wbtc)), _bobBTCAmount, executionOrderFee, initialPriceFeedDatas, false);

    vm.deal(BOB, executionOrderFee);
    usdc.mint(BOB, _bobUSDCAmount);
    addLiquidity(BOB, ERC20(address(usdc)), _bobUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);

    uint256 _lastOrderIndex = liquidityHandler.getLiquidityOrders().length - 1;

    // plp LQ &totalSupply should not be the same
    /*  assertPLPTotalSupply(0);
    assertPLPLiquidity(address(wbtc), 0);
    assertPLPLiquidity(address(usdc), 0);
    assertTokenBalanceOf(address(liquidityHandler), address(wbtc), _aliceBTCAmount);
    assertTokenBalanceOf(address(liquidityHandler), address(usdc), _aliceUSDCAmount + _bobUSDCAmount);
    assertTokenBalanceOf(address(liquidityHandler), address(weth), executionOrderFee * (_lastOrderIndex + 1)); 
    assertEq(_lastOrderIndex, 3); */

    exeutePLPOrder(_lastOrderIndex, initialPriceFeedDatas);
    console.log("USDC IN VAULT", vaultStorage.plpLiquidity(address(usdc)));
    console.log("WBTC IN VAULT", vaultStorage.plpLiquidity(address(wbtc)));

    uint256 plpValueE30 = calculator.getPLPValueE30(false, 0, 0);
    console.log("plpValueE30", plpValueE30);

    console.log("BOB PLP IN HAND", plpV2.balanceOf(BOB));

    // vm.deal(BOB, executionOrderFee);
    // usdc.mint(BOB, 2_499 * 1e6);
    // addLiquidity(BOB, ERC20(address(usdc)), 2_499 * 1e6, executionOrderFee, initialPriceFeedDatas, true);

    vm.deal(BOB, executionOrderFee);
    removeLiquidity(BOB, address(wbtc), 10000 * 1e18, executionOrderFee, initialPriceFeedDatas, true);
    // console.log("USDC IN VAULT", vaultStorage.plpLiquidity(address(usdc)));
    // console.log("WBTC IN VAULT", vaultStorage.plpLiquidity(address(wbtc)));

    // removeLiquidity();
    //  FIND PLP TotalSupply. PLP Price = 1,
    //  Formula Deposit TokenInValue - depositFee - taxRate or TokenInValue -depositFee + RebateRate
    // 1. Alice deposit 1 BTC => (1 * 20000) - 0.3% =  19_940 plp for 1 BTC
    // 2. Alice deposit (20_000 * 1) - 0.3% -

    // assertPLPTotalSupply(19_940 * 1e18);
    // assertPLPLiquidity(address(wbtc), 0.997 * 1e8);
  }
}
