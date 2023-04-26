// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_Base } from "./StakedGlpStrategy_Base.t.fork.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { console } from "forge-std/console.sol";

import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";

contract UnstakedGlpStrategy_ConvertCollateral is StakedGlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_one_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ConvertTokenSuccess() external {
    console.log("vaultStorage", address(vaultStorage));
    //set up alice add Liquidity
    vm.deal(ALICE, 1000e18);
    vm.startPrank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    //manual transfer fsglp
    //alice bring sglp to deposit at plp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);
    console.log("sglpAmount", sglpAmount);
    vm.stopPrank();

    depositCollateral(ALICE, 0, ERC20(address(sglp)), sglpAmount);

    console.log("VAULT STORAGE");
    uint256 vaultglpStakeAmount = IGmxRewardTracker(fglpAddress).stakedAmounts(address(vaultStorage));
    uint256 vaultfglpStakeAmount = IGmxRewardTracker(fsGlpAddress).stakedAmounts(address(vaultStorage));

    uint256 fsglpinPocket = ERC20(fsGlpAddress).balanceOf(address(vaultStorage));
    uint256 fglpinPocket = ERC20(fglpAddress).balanceOf(address(vaultStorage));

    console.log("GLP stake Amount", vaultglpStakeAmount);
    console.log("FGLP stake amount", vaultfglpStakeAmount);
    console.log("POCKET FSGLP", fsglpinPocket);
    console.log("POCKET FGLP", fglpinPocket);

    vm.prank(ALICE);
    crossMarginHandler.convertSGlpCollateral(0, usdcAddress, sglpAmount);
  }

  function testCorrectness_ConvertNativeTokenSuccess() external {
    //set up alice add Liquidity
    vm.deal(ALICE, 1000e18);
    vm.startPrank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    //manual transfer fsglp
    //alice bring sglp to deposit at plp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);
    vm.stopPrank();

    depositCollateral(ALICE, 0, ERC20(address(sglp)), sglpAmount);

    console.log("VAULT STORAGE");
    uint256 vaultglpStakeAmount = IGmxRewardTracker(fglpAddress).stakedAmounts(address(vaultStorage));
    uint256 vaultfglpStakeAmount = IGmxRewardTracker(fsGlpAddress).stakedAmounts(address(vaultStorage));

    uint256 fsglpinPocket = ERC20(fsGlpAddress).balanceOf(address(vaultStorage));
    uint256 fglpinPocket = ERC20(fglpAddress).balanceOf(address(vaultStorage));

    console.log("GLP stake Amount", vaultglpStakeAmount);
    console.log("FGLP stake amount", vaultfglpStakeAmount);
    console.log("POCKET FSGLP", fsglpinPocket);
    console.log("POCKET FGLP", fglpinPocket);

    vm.prank(ALICE);
    crossMarginHandler.convertSGlpCollateral(0, usdcAddress, sglpAmount);
  }
}
