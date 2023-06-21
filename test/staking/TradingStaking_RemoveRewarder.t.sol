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

contract TradingStaking_RemoveRewarder is TradingStaking_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_RemoveRewarder() external {
    tradingStaking.removeRewarderForMarketIndexByIndex(1, ethMarketIndex);

    assertEq(address(ethMarketRewarder), tradingStaking.marketIndexRewarders(ethMarketIndex, 0));
    assertEq(address(ethMarketRewarder3), tradingStaking.marketIndexRewarders(ethMarketIndex, 1));

    // Mint 604800 rewardToken2 to Feeder
    rewardToken2.mint(DAVE, 604800 ether);

    // Alice deposits 100 size
    tradingStaking.deposit(ALICE, ethMarketIndex, 100 * 1e30);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    rewardToken2.approve(address(ethMarketRewarder2), type(uint256).max);
    // Feeder feed rewardToken2 to ethMarketRewarder2
    // 604800 / 7 day rewardPerSec ~= 1 rewardToken2
    ethMarketRewarder2.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // Bob deposits 100 size
    tradingStaking.deposit(BOB, ethMarketIndex, 100 * 1e30);
  }
}
