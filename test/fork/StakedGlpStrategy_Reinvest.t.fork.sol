// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract StakedGlpStrategy_Reinvest is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ClaimSuccess_ReinvestSuccess() external {
    //set up alice add Liquidity
    vm.deal(ALICE, 1000e18);
    vm.prank(ALICE);
    rewardRouter.mintAndStakeGlpETH{ value: 100e18 }(0, 0);

    //alice bring sglp to deposit at hlp liquidity
    uint256 sglpAmount = sglp.balanceOf(ALICE);

    uint256 vaultStorageBeforeAddLq = vaultStorage.hlpLiquidity(sGlpAddress);
    uint256 hlpBefore = hlpV2.balanceOf(ALICE);
    addLiquidity(
      ALICE,
      ERC20Upgradeable(sGlpAddress),
      sglpAmount,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );
    uint256 vaultStorageAfterAddLq = vaultStorage.hlpLiquidity(sGlpAddress);

    assertTrue(vaultStorageAfterAddLq > vaultStorageBeforeAddLq, "Liquidity should increase");
    assertTrue(hlpV2.balanceOf(ALICE) > hlpBefore, "HLP amount of Alice should increase");
    assertEq(sglp.balanceOf(ALICE), 0, "Alice GLP after Add LQ");
    assertEq(rewardTracker.claimable(address(vaultStorage)), 0, "pending reward must be 0");

    skip(10);

    assertTrue(rewardTracker.claimable(address(vaultStorage)) > 0, "pending reward must > 0");

    vm.prank(keeper);
    stakedGlpStrategy.execute();
    assertTrue(
      vaultStorage.hlpLiquidity(sGlpAddress) > vaultStorageAfterAddLq,
      "Liquidity should increase after compounded"
    );
    assertEq(hlpV2.balanceOf(address(stakedGlpStrategy)), 0, "HLP amount of StakedGlpStrategy should be zero");
  }
}
