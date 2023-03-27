// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract TC36 is BaseIntTest_WithActions {
  function test_correctness_MaxUtilization() external {
    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB is open position

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(ALICE, ERC20(address(wbtc)), 100 * 1e8, executionOrderFee, initialPriceFeedDatas, true);

    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 100_000 * 1e6);

    addLiquidity(ALICE, ERC20(address(usdc)), 100_000 * 1e6, executionOrderFee, initialPriceFeedDatas, true);
    {
      // PLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertPLPTotalSupply(2_094_000 * 1e18);
      // assert PLP
      assertTokenBalanceOf(ALICE, address(plpV2), 2_094_000 * 1e18);
      assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertPLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    //  Calculation for Deposit Collateral and Open Position
    //  total usd debt => (99.7*20_000) + 100_000 => 2_094_000
    //  max utilization = 80% = 2_094_000 *0.8 = 1_675_200

    // - reserveValue = imr * maxProfit/BPS
    // - imr = reserveValue /maxProfit * BPS
    // - imr = 1_675_200 / 90000 * 10000 =>  1_675_200 /9 => 186_133.33333333334
    // - open position Size = imr * IMF / BPS
    // - open position Size = imr * 100 => 186133.33333333334 * 100 => 18_613_333.333333334 => 18_613_333
    // - deposit collateral = sizeDelta + (sizeDelta * tradingFeeBPS / BPS)
    // - deposit collateral = 18_613_333 + (18_613_333 * 10/10000)
    // - deposit collateral = 18631946.333

    usdc.mint(BOB, 18_631_946.333 * 1e6);
    depositCollateral(BOB, 0, ERC20(address(usdc)), 18_631_946.333 * 1e6);

    uint256 _pythGasFee = initialPriceFeedDatas.length;
    vm.deal(BOB, _pythGasFee);

    //reserve => 16751999700
    //maxUtilization => 16752000000
    marketBuy(BOB, 0, wbtcMarketIndex, 18_613_333 * 1e30, address(wbtc), initialPriceFeedDatas);

    //remove 1 plp still revert
    vm.deal(ALICE, executionOrderFee);
    uint256 _plpAliceBefore = plpV2.balanceOf(ALICE);
    removeLiquidity(ALICE, address(wbtc), 1 * 1e18, executionOrderFee, initialPriceFeedDatas, true);
    uint256 _plpAliceAfter = plpV2.balanceOf(ALICE);
    assertEq(_plpAliceBefore, _plpAliceAfter, "Alice plp should be the same");
  }
}
