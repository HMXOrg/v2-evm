// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";

abstract contract TradingStaking_Base is BaseTest {
  MockErc20 internal rewardToken1;
  MockErc20 internal rewardToken2;
  MockErc20 internal rewardToken3;
  MockErc20 internal rewardToken4;
  ITradingStaking internal tradingStaking;
  IRewarder internal ethMarketRewarder;
  IRewarder internal ethMarketRewarder2;
  IRewarder internal ethMarketRewarder3;
  IRewarder internal ethMarketRewarder4;

  function setUp() public virtual {
    rewardToken1 = new MockErc20("Reward Token 1", "RWD1", 18);
    rewardToken2 = new MockErc20("Reward Token 2", "RWD2", 18);
    rewardToken3 = new MockErc20("Reward Token 3", "RWD3", 18);
    rewardToken4 = new MockErc20("Reward Token 4", "RWD4", 18);

    tradingStaking = Deployer.deployTradingStaking();

    ethMarketRewarder = Deployer.deployFeedableRewarder("Gov", address(rewardToken1), address(tradingStaking));
    ethMarketRewarder2 = Deployer.deployFeedableRewarder("Something", address(rewardToken2), address(tradingStaking));
    ethMarketRewarder3 = Deployer.deployFeedableRewarder(
      "SomethingElse",
      address(rewardToken3),
      address(tradingStaking)
    );
    ethMarketRewarder4 = Deployer.deployFeedableRewarder(
      "SomethingElse",
      address(rewardToken4),
      address(tradingStaking)
    );

    ethMarketRewarder.setFeeder(DAVE);
    ethMarketRewarder2.setFeeder(DAVE);
    ethMarketRewarder3.setFeeder(DAVE);
    ethMarketRewarder4.setFeeder(DAVE);

    uint256[] memory _marketIndices = new uint256[](1);
    _marketIndices[0] = ethMarketIndex;
    tradingStaking.addRewarder(address(ethMarketRewarder), _marketIndices);
    tradingStaking.addRewarder(address(ethMarketRewarder2), _marketIndices);
    tradingStaking.addRewarder(address(ethMarketRewarder3), _marketIndices);
    tradingStaking.setWhitelistedCaller(address(this));

    // rewardToken.mint(address(this), 100 ether);
    // rewardToken.approve(address(ethMarketRewarder), 100 ether);
    // ethMarketRewarder.feed(100 ether, 365 days);
  }
}
