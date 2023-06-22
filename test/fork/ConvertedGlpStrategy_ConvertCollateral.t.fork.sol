// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// GMX
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

contract ConvertedGlpStrategy_ConvertCollateral is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ConvertTokenSuccess() external {
    //set up alice add Liquidity at GMX
    vm.deal(ALICE, 1000e18);
    vm.startPrank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    uint256 sglpAmount = sglp.balanceOf(ALICE);
    vm.stopPrank();

    depositCollateral(ALICE, 0, sglp, sglpAmount);

    uint256 glpStakeAmount = IGmxRewardTracker(fglpAddress).stakedAmounts(address(vaultStorage));
    uint256 fglpStakeAmount = IGmxRewardTracker(fsGlpAddress).stakedAmounts(address(vaultStorage));

    assertEq(glpStakeAmount, sglpAmount, "glp stake amount");
    assertEq(fglpStakeAmount, sglpAmount, "fglp stake amount");

    vaultStorage.setStrategyFunctionSigAllowance(
      address(sglp),
      address(convertedGlpStrategy),
      IGmxRewardRouterV2.unstakeAndRedeemGlp.selector
    );

    vm.prank(ALICE);
    uint256 amountOut = crossMarginHandler.convertSGlpCollateral(0, usdcAddress, sglpAmount, 0);

    assertEq(vaultStorage.traderBalances(ALICE, address(sglp)), 0, "trader balance sglp should be 0");
    assertEq(vaultStorage.traderBalances(ALICE, address(usdc)), amountOut, "trader balance sglp should be 0");
  }

  function testCorrectness_ConvertNativeTokenSuccess() external {
    //set up alice add Liquidity at GMX
    vm.deal(ALICE, 1000e18);
    vm.startPrank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    uint256 sglpAmount = sglp.balanceOf(ALICE);
    vm.stopPrank();

    depositCollateral(ALICE, 0, sglp, sglpAmount);

    uint256 glpStakeAmount = IGmxRewardTracker(fglpAddress).stakedAmounts(address(vaultStorage));
    uint256 fglpStakeAmount = IGmxRewardTracker(fsGlpAddress).stakedAmounts(address(vaultStorage));

    assertEq(glpStakeAmount, sglpAmount, "glp stake amount");
    assertEq(fglpStakeAmount, sglpAmount, "fglp stake amount");

    vm.prank(ALICE);
    uint256 amountOut = crossMarginHandler.convertSGlpCollateral(0, wethAddress, sglpAmount, 0);

    assertEq(vaultStorage.traderBalances(ALICE, address(sglp)), 0, "trader balance sglp should be 0");
    assertEq(vaultStorage.traderBalances(ALICE, address(weth)), amountOut, "trader balance sglp should be 0");
  }
}
