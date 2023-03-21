// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { TradingStaking_Base } from "./TradingStaking_Base.t.sol";

contract TradingStaking_Withdraw is TradingStaking_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenWithdrawNotDistributeReward() external {
    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice withdraw 30 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 30 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 70 * 1e30);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Alice withdraw 70 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 70 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 0);
    assertEq(ethMarketRewarder.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder3.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), 0);
  }

  function testCorrectness_WhenRewardOffBeforeWithdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken2 to Feeder
    rewardToken2.mint(DAVE, 604800 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    rewardToken2.approve(address(ethMarketRewarder2), type(uint256).max);
    // Feeder feed rewardToken2 to ethMarketRewarder2
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken2
    ethMarketRewarder2.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 8 days
    vm.warp(block.timestamp + 8 days);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    assertEq(ethMarketRewarder2.lastRewardTime(), 1);
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 604800 ether);

    // Alice withdraw 100 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 100 * 1e30);

    // 604800 * 1 / 100 = 6048
    assertEq(ethMarketRewarder2.accRewardPerShare(), 6048 ether);
    // 100 * 0.006048 * 1e6 = 604800
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), -604800 ether);
    // 8 days
    assertEq(ethMarketRewarder2.lastRewardTime(), 691201);
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 604800 ether);
  }

  function testCorrectness_WhenWithdrawUtilRewardOffStillWithdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 rewardToken2 to Feeder
    rewardToken2.mint(DAVE, 604800 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    rewardToken2.approve(address(ethMarketRewarder2), type(uint256).max);
    // Feeder feed rewardToken2 to ethMarketRewarder2
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken2
    ethMarketRewarder2.feed(604800 ether, 7 days);
    vm.stopPrank();

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    // 4 days * 1 / 100 = 0.00003456
    assertEq(ethMarketRewarder2.accRewardPerShare(), 0);
    // 100 * 0.003456 * 1e6 = 345600
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), 0);
    // 4 days
    assertEq(ethMarketRewarder2.lastRewardTime(), 1);

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    // Alice withdraw 30 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 30 * 1e30);

    // 4 days = 345600
    // 345600 * 1 / 100 = 3456
    assertEq(ethMarketRewarder2.accRewardPerShare(), 3456 ether);
    // 30 * 0.003456 * 1e6 = 103680
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), -103680 ether);
    // 345600
    assertEq(ethMarketRewarder2.lastRewardTime(), 345601);

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    // 7 days * 1 * 100 / 100 ~= 604800 || 604799999999999940000000
    assertApproxEqAbs(ethMarketRewarder2.pendingReward(ALICE), 604800 ether, 100);

    // Bob withdraw 70 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 70 * 1e30);

    // 4 days = 259200
    // 345600 + (259200 * 1 / 70) = 7158.8571428571
    assertApproxEqAbs(ethMarketRewarder2.accRewardPerShare(), 7158.8571428571 ether, 0.00000001 ether);
    // 103680 + 70 * 0.007158857142857142 * 1e6 = 604799.99999999994
    assertApproxEqAbs(ethMarketRewarder2.userRewardDebts(ALICE), -604799.99999999994 ether, 0.00000001 ether);
    // 8 days
    assertEq(ethMarketRewarder2.lastRewardTime(), 691201);
  }

  function testCorrectness_Withdraw() external {
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

    // Alice withdraw 100 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 100 * 1e30);
    // 3 days = 259200
    // 259200 * 1 / 300 = 864
    assertEq(ethMarketRewarder2.accRewardPerShare(), 864 ether);
    // 100 * 0.000864 * 1e6 = 86400
    assertEq(ethMarketRewarder2.userRewardDebts(ALICE), -86400 ether);
    // 259200 3 hours
    assertEq(ethMarketRewarder2.lastRewardTime(), 270001);
    // 259200 * 0.5 / 300 = 432
    assertEq(ethMarketRewarder.accRewardPerShare(), 432 ether);
    // 100 * 0.000432 * 1e6 = 43200
    assertEq(ethMarketRewarder.userRewardDebts(ALICE), -43200 ether);
    // 259200 3 hours
    assertEq(ethMarketRewarder.lastRewardTime(), 270001);
    // 259200 * 0.1 / 300 = 86.40
    assertEq(ethMarketRewarder3.accRewardPerShare(), 86.40 ether);
    // 100 * 0.0000864 * 1e6 = 8640
    assertEq(ethMarketRewarder3.userRewardDebts(ALICE), -8640 ether);
    // 259200 3 hours
    assertEq(ethMarketRewarder3.lastRewardTime(), 270001);

    // 259200 * 1 * 100 / 300 = 172800
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 172800 ether);
    // 259200 * 0.5 * 100 / 150 = 86400
    assertEq(ethMarketRewarder.pendingReward(ALICE), 86400 ether);
    // 259200 * 0.1 * 100 / 150 = 17280
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 17280 ether);
    // 259200 * 1 * 50 / 150 = 86400
    assertEq(ethMarketRewarder2.pendingReward(BOB), 86400 ether);
    // 259200 * 0.5 * 50 / 150 = 43200
    assertEq(ethMarketRewarder.pendingReward(BOB), 43200 ether);
    // 259200 * 0.1 * 50 / 150 = 8640
    assertEq(ethMarketRewarder3.pendingReward(BOB), 8640 ether);

    // after 5 days
    vm.warp(block.timestamp + 5 days);

    // 172800 + 4 days * 1 * 100 / 200 = 345600
    assertEq(ethMarketRewarder2.pendingReward(ALICE), 345600 ether);
    // 86400 + 4 days * 0.5 * 100 / 200 = 172800
    assertEq(ethMarketRewarder.pendingReward(ALICE), 172800 ether);
    // 17280 + 4 days * 0.1 * 100 / 200 = 34560
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 34560 ether);
    // 86400 + 4 days * 1 * 100 / 200 = 259200
    assertEq(ethMarketRewarder2.pendingReward(BOB), 259200 ether);
    // 43200 + 4 days * 0.5 * 100 / 200 = 129600
    assertEq(ethMarketRewarder.pendingReward(BOB), 129600 ether);
    // 8640 + 4 days * 0.1 * 100 / 200 = 25920
    assertEq(ethMarketRewarder3.pendingReward(BOB), 25920 ether);

    // Alice withdraw 100 size
    tradingStaking.withdraw(ALICE, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 0 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Bob withdraw 100 size
    tradingStaking.withdraw(BOB, ethMarketIndex, 100 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, BOB), 0 ether);

    assertEq(ethMarketRewarder2.pendingReward(ALICE), 345600 ether);
    assertEq(ethMarketRewarder.pendingReward(ALICE), 172800 ether);
    assertEq(ethMarketRewarder3.pendingReward(ALICE), 34560 ether);
    assertEq(ethMarketRewarder2.pendingReward(BOB), 259200 ether);
    assertEq(ethMarketRewarder.pendingReward(BOB), 129600 ether);
    assertEq(ethMarketRewarder3.pendingReward(BOB), 25920 ether);
  }

  function testCorrectness_AliceShouldNotForceBobToWithdraw() external {
    tradingStaking.deposit(ALICE, ethMarketIndex, 80 * 1e30);

    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);

    vm.expectRevert(abi.encodeWithSignature("TradingStaking_InsufficientTokenAmount()"));
    tradingStaking.withdraw(ALICE, ethMarketIndex, 100 * 1e30);
    tradingStaking.withdraw(ALICE, ethMarketIndex, 80 * 1e30);

    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, BOB), 100 * 1e30);
    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), 0 ether);
  }
}
