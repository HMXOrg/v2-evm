// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_BaseForkTest } from "./StakedGlpStrategy_Base.t.fork.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console } from "forge-std/console.sol";

contract StakedGlpStrategy_ForkTest is StakedGlpStrategy_BaseForkTest {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  // address usdcOwner = 0x98e4db7e07e584f89a2f6043e7b7c89dc27769ed;

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ClaimSuccess_ReinvestSuccess() external {
    //set up alice add Liquidity and 10 blocked passed
    vm.prank(ALICE);
    gmxRewardRouterV2.mintAndStakeGlpETH{ value: 100e18 }(0, 0);
    skip(10);

    //alice bring sglp to deposit at hlp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);
    console.log("sglpAmount", sglpAmount);

    addLiquidity(ALICE, ERC20(sGlpAddress), sglpAmount, executionOrderFee, new bytes[](0), true);

    sglpAmount = sglp.balanceOf(ALICE);
    console.log("sglpAmount", sglpAmount);
    // glpFeeTracker.claim(ALICE);

    // _wethBalance = weth.balanceOf(ALICE);
  }
}
