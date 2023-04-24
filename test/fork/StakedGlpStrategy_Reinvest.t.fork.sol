// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_Base } from "./StakedGlpStrategy_Base.t.fork.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

contract StakedGlpStrategy_Reinvest is StakedGlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_one_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ClaimSuccess_ReinvestSuccess() external {
    //set up alice add Liquidity
    vm.deal(ALICE, 1000e18);
    vm.prank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    //alice bring sglp to deposit at plp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);

    uint256 vaultStorageBeforeAddLq = vaultStorage.plpLiquidity(sGlpAddress);
    uint256 plpBefore = plpV2.balanceOf(ALICE);
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
    uint256 vaultStorageAfterAddLq = vaultStorage.plpLiquidity(sGlpAddress);

    assertTrue(vaultStorageAfterAddLq > vaultStorageBeforeAddLq, "Liquidity should increase");
    assertTrue(plpV2.balanceOf(ALICE) > plpBefore, "PLP amount of Alice should increase");
    assertEq(sglp.balanceOf(ALICE), 0, "Alice GLP after Add LQ");
    assertEq(rewardTracker.claimable(address(vaultStorage)), 0, "pending reward must be 0");

    skip(10);

    assertTrue(rewardTracker.claimable(address(vaultStorage)) > 0, "pending reward must > 0");

    vm.prank(keeper);
    stakedGlpStrategy.execute();
    assertTrue(
      vaultStorage.plpLiquidity(sGlpAddress) > vaultStorageAfterAddLq,
      "Liquidity should increase after compounded"
    );
    assertEq(plpV2.balanceOf(address(stakedGlpStrategy)), 0, "PLP amount of StakedGlpStrategy should be zero");
  }
}
