// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_Base } from "./StakedGlpStrategy_Base.t.fork.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

contract StakedGlpStrategy_Reinvest is StakedGlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ClaimSuccess_ReinvestSuccess() external {
    //set up alice add Liquidity
    vm.prank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    //alice bring sglp to deposit at plp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);

    addLiquidity(
      ALICE,
      ERC20(sGlpAddress),
      sglpAmount,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    liquidityTester.assertLiquidityInfo(
      LiquidityTester.LiquidityExpectedData({
        token: address(sglp),
        who: ALICE,
        lpTotalSupply: 183869983524555116065486,
        totalAmount: 189873700974259579939141,
        plpLiquidity: 189304079871336801199324,
        plpAmount: 183869983524555116065486,
        fee: 569621102922778739817,
        executionFee: executionOrderFee
      })
    );

    assertEq(0, sglp.balanceOf(ALICE), "Alice GLP after Add LQ");

    uint256 reward = rewardTracker.claimable(address(vaultStorage));
    assertEq(0, reward, "pending reward must be 0");

    skip(10);
    reward = rewardTracker.claimable(address(vaultStorage));
    assertEq(reward > 0, true, "pending reward must > 0");

    vm.prank(keeper);
    stakedGlpStrategy.execute();

    liquidityTester.assertLiquidityInfo(
      LiquidityTester.LiquidityExpectedData({
        token: address(sglp),
        who: address(stakedGlpStrategy),
        lpTotalSupply: 183869983524555116065486, //lpTotalSupply has to be the same
        totalAmount: 189873712489801202222370, // totalAmount should increase
        plpLiquidity: 189304091386878423482553, // plp liquidity should increase
        plpAmount: 0, // plpAmount after reinvest and deposit to pool
        fee: 569621102922778739817, //fee has to be the same.
        executionFee: executionOrderFee //executionFee has to be the same.
      })
    );
  }
}
