// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { TradingStaking_Base } from "./TradingStaking_Base.t.sol";

contract TradingStaking_Deposit is TradingStaking_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenDepositNotDistributeReward() external {
    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 100 * 1e30);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice deposit 100 HLP
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 200 * 1e30);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 0);
  }

  function testCorrectness_WhenFeedRewardAfterDeposit() external {
    // Mint 604800 rewardToken1 to Feeder
    rewardToken1.mint(DAVE, 604800 ether);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    rewardToken1.approve(address(ethMarketRewarder), type(uint256).max);
    // Feeder feed rewardToken1 to ethMarketRewarder
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken1
    ethMarketRewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 1 hours * 1 * 100 / 100 = 3600
    assertEq(ethMarketRewarder.pendingReward(ALICE), 3600 ether);

    // Bob deposits 100 ether
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    // 3600 * 1 / 100 = 36
    assertEq(ethMarketRewarder.accRewardPerShare(), 36 ether);
    // 100 * 0.000036 * 1e6 = 3600
    assertEq(ethMarketRewarder.userRewardDebts(BOB), 3600 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 3600 + (1 hours * 1 * 100 / 200) = 5400
    assertEq(ethMarketRewarder.pendingReward(ALICE), 5400 ether);
    // 1 hours * 1 * 100 / 200 = 1800
    assertEq(ethMarketRewarder.pendingReward(BOB), 1800 ether);
  }

  function testCorrectness_WhenAddRewarderAferDeposit() external {
    // Mint 604800 rewardToken4 to Feeder
    rewardToken4.mint(DAVE, 604800 ether);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Add rewardToken4 Rewarder
    uint256[] memory _marketIndices = new uint256[](1);
    _marketIndices[0] = ethMarketIndex;
    tradingStaking.addRewarder(address(ethMarketRewarder4), _marketIndices);

    vm.startPrank(DAVE);
    rewardToken4.approve(address(ethMarketRewarder4), type(uint256).max);
    // Feeder feed rewardToken4 to ethMarketRewarder4
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken4
    ethMarketRewarder4.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 1 hours * 1 * 100 / 100 = 3600
    assertEq(ethMarketRewarder4.pendingReward(ALICE), 3600 ether);

    // Bob deposits 100 size
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    // 3600 * 1 / 100 = 3600
    assertEq(ethMarketRewarder4.accRewardPerShare(), 36 ether);
    // 100 * 0.000036 * 1e6 = 3600
    assertEq(ethMarketRewarder4.userRewardDebts(BOB), 3600 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 3600 + (1 hours * 1 * 100 / 200) = 5400
    assertEq(ethMarketRewarder4.pendingReward(ALICE), 5400 ether);
    // 1 hours * 1 * 100 / 200 = 1800
    assertEq(ethMarketRewarder4.pendingReward(BOB), 1800 ether);
  }

  function testCorrectness_WhenRewardOffBeforeDeposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken1 to Feeder
    rewardToken1.mint(DAVE, 604800 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + 8 days);

    vm.startPrank(DAVE);
    rewardToken1.approve(address(ethMarketRewarder), type(uint256).max);
    // Feeder feed rewardToken1 to ethMarketRewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    ethMarketRewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 8 days
    vm.warp(block.timestamp + 8 days);

    // Alice deposits 100 HLP
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder.lastRewardTime(), 691201);
    assertEq(ethMarketRewarder.pendingReward(ALICE), 604800 ether);

    // Bob deposits 100 HLP
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    // 7 days * 1 / 100 = 6048
    assertEq(ethMarketRewarder.accRewardPerShare(), 6048 ether);
    assertEq(ethMarketRewarder.userRewardDebts(BOB), 604800 ether);
    // 8 days
    assertEq(ethMarketRewarder.lastRewardTime(), 1382401);
    assertEq(ethMarketRewarder.pendingReward(BOB), 0);
  }

  function testCorrectness_WhenDepositUtilRewardOffStillDeposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken1 to Feeder
    rewardToken1.mint(DAVE, 604800 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    rewardToken1.approve(address(ethMarketRewarder), type(uint256).max);
    // Feeder feed rewardToken1 to ethMarketRewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    ethMarketRewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    // Alice deposits 100 HLP
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder.lastRewardTime(), 1);

    // after 8 days
    vm.warp(block.timestamp + 8 days);

    // 7 days * 1 * 100 / 100 = 604800
    assertEq(ethMarketRewarder.pendingReward(ALICE), 604800 ether);

    // Bob deposits 100 HLP
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    assertEq(ethMarketRewarder.pendingReward(BOB), 0);
    // 7 days * 1 / 100 = 6048
    assertEq(ethMarketRewarder.accRewardPerShare(), 6048 ether);
    // 100 * 0.00604800 * 1e6 = 604800
    assertEq(ethMarketRewarder.userRewardDebts(BOB), 604800 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice deposits 100 HLP
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(ethMarketRewarder.pendingReward(ALICE), 604800 ether);
    // 7 days * 1 / 100 = 6048
    assertEq(ethMarketRewarder.accRewardPerShare(), 6048 ether);
    // 100 * 0.00604800 * 1e6 = 604800
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 604800 ether);
  }

  function testCorrectness_Deposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken1 to Feeder
    rewardToken1.mint(DAVE, 604800 ether);
    // Mint 302400 rewardToken2 to Feeder
    rewardToken2.mint(DAVE, 302400 ether);
    // Mint 60480 rewardToken3 to Feeder
    rewardToken3.mint(DAVE, 60480 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 100 * 1e30);
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder.lastRewardTime(), 1);
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.lastRewardTime(), 1);
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder3.lastRewardTime(), 1);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Bob deposits 50 size
    tradingStaking.deposit(BOB, ethMarketIndex, 50 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, BOB), 50 * 1e30);
    assertEq(ethMarketRewarder.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(ethMarketRewarder.lastRewardTime(), 7201);
    assertEq(ethMarketRewarder2.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(ethMarketRewarder2.lastRewardTime(), 7201);
    assertEq(ethMarketRewarder3.pendingReward(BOB), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(ethMarketRewarder3.lastRewardTime(), 7201);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    rewardToken1.approve(address(ethMarketRewarder), type(uint256).max);
    // Feeder feed rewardToken1 to ethMarketRewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    ethMarketRewarder.feed(604800 ether, 7 days);

    rewardToken2.approve(address(ethMarketRewarder2), type(uint256).max);
    // Feeder feed rewardToken2 to ethMarketRewarder2
    // 302400 / 7 day rewardPerSec ~= 0.5 rewardToken2
    ethMarketRewarder2.feed(302400 ether, 7 days);

    rewardToken3.approve(address(ethMarketRewarder3), type(uint256).max);
    // Feeder feed rewardToken3 to ethMarketRewarder3
    // 60480 / 7 day rewardPerSec ~= 0.1 rewardToken3
    ethMarketRewarder3.feed(60480 ether, 7 days);
    vm.stopPrank();

    // 3 hours
    assertEq(ethMarketRewarder.lastRewardTime(), 10801);
    // 3 hours
    assertEq(ethMarketRewarder2.lastRewardTime(), 10801);
    // 3 hours
    assertEq(ethMarketRewarder3.lastRewardTime(), 10801);

    // after 3 days
    vm.warp(block.timestamp + 3 days);

    // 3 days * 1 * 100 / 150 = 172800
    assertEq(ethMarketRewarder.pendingReward(ALICE), 172800 ether);
    // 3 days * 0.5 * 100 / 150 = 86400
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 86400 ether);
    // 3 days * 0.1 * 100 / 150 = 17280
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 17280 ether);
    // 3 days * 1 * 50 / 150 = 86400
    assertEq(ethMarketRewarder.pendingReward(BOB), 86400 ether);
    // 3 days * 0.5 * 50 / 150 = 43200
    assertEq(ethMarketRewarder2.pendingReward(BOB), 43200 ether);
    // 3 days * 0.1 * 50 / 150 = 8640
    assertEq(ethMarketRewarder3.pendingReward(BOB), 8640 ether);

    // Alice deposits 50 size
    tradingStaking.deposit(BOB, ethMarketIndex, 50 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, BOB), 100 * 1e30);
    // 3 days * 1 / 150 = 1728
    assertEq(ethMarketRewarder.accRewardPerShare(), 1728 ether);
    // 50 * 0.001728 * 1e6 = 86400
    assertEq(ethMarketRewarder.userRewardDebts(BOB), 86400 ether);
    // 3 days 3 hours
    assertEq(ethMarketRewarder.lastRewardTime(), 270001);
    // 3 days * 0.5 / 150 = 864
    assertEq(ethMarketRewarder2.accRewardPerShare(), 864 ether);
    // 50 * 0.000864 * 1e6 = 43200
    assertEq(ethMarketRewarder2.userRewardDebts(BOB), 43200 ether);
    // 3 days 3 hours
    assertEq(ethMarketRewarder2.lastRewardTime(), 270001);
    // 3 days * 0.1 / 150 = 172.8
    assertEq(ethMarketRewarder3.accRewardPerShare(), 172.8 ether);
    // 50 * 0.0001728 * 1e6 = 8640
    assertEq(ethMarketRewarder3.userRewardDebts(BOB), 8640 ether);
    // 3 days 3 hours
    assertEq(ethMarketRewarder3.lastRewardTime(), 270001);

    // 3 days * 1 * 100 / 150 = 172800
    assertEq(ethMarketRewarder.pendingReward(ALICE), 172800 ether);
    // 3 days * 0.5 * 100 / 150 = 86400
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 86400 ether);
    // 3 days * 0.1 * 100 / 150 = 17280
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 17280 ether);
    // 3 days * 1 * 50 / 150 = 86400
    assertEq(ethMarketRewarder.pendingReward(BOB), 86400 ether);
    // 3 days * 0.5 * 50 / 150 = 43200
    assertEq(ethMarketRewarder2.pendingReward(BOB), 43200 ether);
    // 3 days * 0.1 * 50 / 150 = 8640
    assertEq(ethMarketRewarder3.pendingReward(BOB), 8640 ether);

    // after 5 days
    vm.warp(block.timestamp + 5 days);

    // 172800 + 4 days * 1 * 100 / 200 = 345600
    assertEq(ethMarketRewarder.pendingReward(ALICE), 345600 ether);
    // 86400 + 4 days * 0.5 * 100 / 200 = 172800
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 172800 ether);
    // 17280 + 4 days * 0.1 * 100 / 200 = 34560
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 34560 ether);
    // 86400 + 4 days * 1 * 100 / 200 = 259200
    assertEq(ethMarketRewarder.pendingReward(BOB), 259200 ether);
    // 43200 + 4 days * 0.5 * 100 / 200 = 129600
    assertEq(ethMarketRewarder2.pendingReward(BOB), 129600 ether);
    // 8640 + 4 days * 0.1 * 100 / 200 = 25920
    assertEq(ethMarketRewarder3.pendingReward(BOB), 25920 ether);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 200 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Bob deposits 100 size
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, BOB), 200 * 1e30);

    assertEq(ethMarketRewarder.pendingReward(ALICE), 345600 ether);
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 172800 ether);
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 34560 ether);
    assertEq(ethMarketRewarder.pendingReward(BOB), 259200 ether);
    assertEq(ethMarketRewarder2.pendingReward(BOB), 129600 ether);
    assertEq(ethMarketRewarder3.pendingReward(BOB), 25920 ether);
  }
}
