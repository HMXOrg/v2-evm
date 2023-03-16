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
    /* 
    vm.deal(BOB, executionOrderFee);
    uint256 _bobUSDCAmount = 1_000 * 1e6;
    usdc.mint(BOB, _bobUSDCAmount);
    addLiquidity(BOB, ERC20(address(usdc)), _bobUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);
 */
    uint256 _lastOrderIndex = liquidityHandler.getLiquidityOrders().length - 1;

    exeutePLPOrder(_lastOrderIndex, initialPriceFeedDatas);

    /* assertPLPTotalSupply(19_940 * 1e18);
    assertVaultTokenBalance(address(wbtc), 1 * 1e8);
    assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _fundingFee: 0, _devFee: 0 });
    assertPLPLiquidity(address(wbtc), 0.997 * 1e8);
    // check to prove transfer corrected amount from liquidity provider
    assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8); */
  }
}
