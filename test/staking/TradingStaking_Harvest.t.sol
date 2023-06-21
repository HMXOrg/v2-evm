// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { TradingStaking_Base } from "./TradingStaking_Base.t.sol";

contract TradingStaking_Harvest is TradingStaking_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_Harvest() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken2 to Feeder
    rewardToken2.mint(DAVE, 604800 ether);
    // Mint 302400 rewardToken1 to Feeder
    rewardToken1.mint(DAVE, 302400 ether);
    // Mint 60480 rewardToken3 to Feeder
    rewardToken3.mint(DAVE, 60480 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice deposits 200 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 200 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Bob deposits 100 size
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    rewardToken2.approve(address(ethMarketRewarder2), type(uint256).max);
    // Feeder feed rewardToken2 to ethMarketRewarder2
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken2
    ethMarketRewarder2.feed(604800 ether, 7 days);

    rewardToken1.approve(address(ethMarketRewarder), type(uint256).max);
    // Feeder feed rewardToken1 to ethMarketRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 rewardToken1
    ethMarketRewarder.feed(302400 ether, 7 days);

    rewardToken3.approve(address(ethMarketRewarder3), type(uint256).max);
    // Feeder feed rewardToken3 to ethMarketRewarder3
    // 60480 / 7 day rewardPerSec ~= 0.1 rewardToken3
    ethMarketRewarder3.feed(60480 ether, 7 days);
    vm.stopPrank();

    // after 3 days
    vm.warp(block.timestamp + 3 days);

    // 3 days * 1 * 200 / 300 = 172800
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 172800 ether);
    // 3 days * 0.5 * 200 / 300 = 86400
    assertEq(ethMarketRewarder.pendingReward(ALICE), 86400 ether);
    // 3 days * 0.1 * 200 / 300 = 17280
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 17280 ether);
    // 3 days * 1 * 100 / 300 = 86400
    assertEq(ethMarketRewarder2.pendingReward(BOB), 86400 ether);
    // 3 days * 0.5 * 100 / 300 = 43200
    assertEq(ethMarketRewarder.pendingReward(BOB), 43200 ether);
    // 3 days * 0.1 * 100 / 300 = 8640
    assertEq(ethMarketRewarder3.pendingReward(BOB), 8640 ether);

    {
      vm.startPrank(ALICE);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(ethMarketRewarder);
      rewarders[1] = address(ethMarketRewarder2);
      rewarders[2] = address(ethMarketRewarder3);
      // Alice harvest
      tradingStaking.harvest(rewarders);
      vm.stopPrank();
    }

    assertEq(rewardToken2.balanceOf(ALICE), 172800 ether);
    assertEq(rewardToken1.balanceOf(ALICE), 86400 ether);
    assertEq(rewardToken3.balanceOf(ALICE), 17280 ether);

    assertEq(ethMarketRewarder2.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 0);

    // Alice withdraw 100 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 100 * 1e30);
    // 3 days * 1 / 300 = 864
    assertEq(ethMarketRewarder2.accRewardPerShare(), 864 ether);
    // 100 * 0.000864 * 1e6 = 86400
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 86400 ether);
    // 3 days * 0.5 / 300 = 432
    assertEq(ethMarketRewarder.accRewardPerShare(), 432 ether);
    // 100 * 0.000432 * 1e6 = 43200
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 43200 ether);
    // 3 days * 0.1 / 300 = 86.4
    assertEq(ethMarketRewarder3.accRewardPerShare(), 86.40 ether);
    // 100 * 0.0000864 * 1e6 = 8640
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 8640 ether);

    // after 1 days
    vm.warp(block.timestamp + 1 days);

    // 1 days * 1 * 100 / 200 = 43200
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 43200 ether);
    // 1 days * 0.5 * 100 / 200 = 21600
    assertEq(ethMarketRewarder.pendingReward(ALICE), 21600 ether);
    // 1 days * 0.1 * 100 / 200 = 4320
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 4320 ether);
    // 86400 + 1 days * 1 * 100 / 200 = 129600
    assertEq(ethMarketRewarder2.pendingReward(BOB), 129600 ether);
    // 43200 + 1 days * 0.5 * 100 / 200 = 64800
    assertEq(ethMarketRewarder.pendingReward(BOB), 64800 ether);
    // 8640 + 1 days * 0.1 * 100 / 200 = 12960
    assertEq(ethMarketRewarder3.pendingReward(BOB), 12960 ether);

    {
      vm.startPrank(BOB);
      address[] memory rewarders = new address[](1);
      rewarders[0] = address(ethMarketRewarder);
      // Bob harvest
      tradingStaking.harvest(rewarders);
      vm.stopPrank();
    }

    assertEq(rewardToken2.balanceOf(BOB), 0);
    assertEq(rewardToken1.balanceOf(BOB), 64800 ether);
    assertEq(rewardToken3.balanceOf(BOB), 0);

    assertEq(ethMarketRewarder2.pendingReward(BOB), 129600 ether);
    assertEq(ethMarketRewarder.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder3.pendingReward(BOB), 12960 ether);

    // after 5 days
    vm.warp(block.timestamp + 5 days);

    // 43200 + 3 days * 1 * 100 / 200 = 172800
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 172800 ether);
    // 21600 + 3 days * 0.5 * 100 / 200 = 86400
    assertEq(ethMarketRewarder.pendingReward(ALICE), 86400 ether);
    // 4320 + 3 days * 0.1 * 100 / 200 = 17280
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 17280 ether);
    // 129600 + 3 days * 1 * 100 / 200 = 259200
    assertEq(ethMarketRewarder2.pendingReward(BOB), 259200 ether);
    // 3 days * 0.5 * 100 / 200 = 64800
    assertEq(ethMarketRewarder.pendingReward(BOB), 64800 ether);
    // 12960 + 3 days * 0.1 * 100 / 200 = 25920
    assertEq(ethMarketRewarder3.pendingReward(BOB), 25920 ether);

    {
      vm.startPrank(ALICE);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(ethMarketRewarder);
      rewarders[1] = address(ethMarketRewarder2);
      rewarders[2] = address(ethMarketRewarder3);
      // Alice harvest
      tradingStaking.harvest(rewarders);
      vm.stopPrank();
    }

    {
      vm.startPrank(BOB);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(ethMarketRewarder);
      rewarders[1] = address(ethMarketRewarder2);
      rewarders[2] = address(ethMarketRewarder3);
      // Bob harvest
      tradingStaking.harvest(rewarders);
      vm.stopPrank();
    }
    assertEq(rewardToken2.balanceOf(ALICE), 345600 ether);
    assertEq(rewardToken1.balanceOf(ALICE), 172800 ether);
    assertEq(rewardToken3.balanceOf(ALICE), 34560 ether);
    assertEq(rewardToken2.balanceOf(BOB), 259200 ether);
    assertEq(rewardToken1.balanceOf(BOB), 129600 ether);
    assertEq(rewardToken3.balanceOf(BOB), 25920 ether);

    assertEq(ethMarketRewarder2.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder2.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder3.pendingReward(BOB), 0);
  }
}
