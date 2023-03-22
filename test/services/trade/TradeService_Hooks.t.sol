// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockErc20 } from "../../mocks/MockErc20.sol";
import { TradeService_Base } from "./TradeService_Base.t.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";
import { ITraderLoyaltyCredit } from "@hmx/tokens/interfaces/ITraderLoyaltyCredit.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TradeService_Hooks is TradeService_Base {
  MockErc20 internal rewardToken;
  ITraderLoyaltyCredit internal tlc;
  ITradingStaking internal tradingStaking;
  ITradeServiceHook internal tradingStakingHook;
  ITradeServiceHook internal tlcHook;
  IRewarder internal ethMarketRewarder;

  function setUp() public virtual override {
    super.setUp();

    rewardToken = new MockErc20("Reward Token", "RWD", 18);
    tradingStaking = Deployer.deployTradingStaking();
    tradingStakingHook = Deployer.deployTradingStakingHook(address(tradingStaking), address(tradeService));
    tlc = Deployer.deployTLCToken(address(rewardToken));
    tlcHook = Deployer.deployTLCHook(address(tradeService), address(tlc));

    address[] memory _hooks = new address[](2);
    _hooks[0] = address(tradingStakingHook);
    _hooks[1] = address(tlcHook);
    configStorage.setTradeServiceHooks(_hooks);

    ethMarketRewarder = Deployer.deployFeedableRewarder("Gov", address(rewardToken), address(tradingStaking));

    uint256[] memory _marketIndices = new uint256[](1);
    _marketIndices[0] = ethMarketIndex;
    tradingStaking.addRewarder(address(ethMarketRewarder), _marketIndices);
    tradingStaking.setWhitelistedCaller(address(tradingStakingHook));

    rewardToken.mint(address(this), 100 ether);
    rewardToken.approve(address(ethMarketRewarder), 100 ether);
    ethMarketRewarder.feed(100 ether, 365 days);

    tlc.setMinter(address(tlcHook), true);

    rewardToken.mint(address(this), 300 ether);
    rewardToken.approve(address(tlc), 300 ether);
    tlc.feedReward(tlc.getCurrentEpochTimestamp(), 300 ether);
  }

  function testRevert_TradingStaking_UnknownMarketIndex() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = 1_000_000 * 1e30;

    vm.expectRevert(abi.encodeWithSignature("TradingStaking_UnknownMarketIndex()"));
    tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);
  }

  function testRevert_TradingStaking_Forbidden() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = 1_000_000 * 1e30;

    tradingStaking.setWhitelistedCaller(address(ALICE));
    vm.expectRevert(abi.encodeWithSignature("TradingStaking_Forbidden()"));
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
  }

  function testRevert_TradingStakingHook_Forbidden() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = 1_000_000 * 1e30;

    vm.expectRevert(abi.encodeWithSignature("TradingStakingHook_Forbidden()"));
    tradingStakingHook.onIncreasePosition(ALICE, 0, ethMarketIndex, uint256(sizeDelta), "");
  }

  function testCorrectness_hookOnIncreaseAndDecreasePosition() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = 1_000_000 * 1e30;

    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), uint256(sizeDelta));
    assertEq(IERC20(address(tlc)).balanceOf(ALICE), 1_000_000 * 1e18);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 300 * 1e30, address(wbtc), price);
    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), uint256(sizeDelta - 300 * 1e30));
    assertEq(IERC20(address(tlc)).balanceOf(ALICE), 1_000_300 * 1e18);
  }

  function testCorrectness_pendingRewardAndClaim() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // Alice open a position with $1,000,000 in size
    // Bob open a position with $400,000 in size
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);
    tradeService.increasePosition(BOB, 0, ethMarketIndex, 400_000 * 1e30, 0);

    // Pending reward for both trading staking and TLC should be zero.
    // because time has not passed.
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0 ether);
    assertEq(ethMarketRewarder.pendingReward(BOB), 0 ether);
    assertEq(tlc.pendingReward(0, 1, ALICE), 0 ether);
    assertEq(tlc.pendingReward(0, 1, BOB), 0 ether);

    vm.warp(block.timestamp + 3 days);
    // timePast = 60 * 60 * 24 * 3 = 259200
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Alice's share = 1,000,000 * 1e30
    // totalShare = 1,400,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (259200 / 31536000) * 100 * 1e18 * ((1000000 * 1e30)/(1400000 * 1e30))
    //               = 0.587084148727984344
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0.587084148727 ether);
    // timePast = 60 * 60 * 24 * 3 = 259200
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Bob's share = 400,000 * 1e30
    // totalShare = 1,400,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (259200 / 31536000) * 100 * 1e18 * ((400000 * 1e30)/(1400000 * 1e30))
    //               = 0.234833659490800000
    assertEq(ethMarketRewarder.pendingReward(BOB), 0.234833659490800000 ether);
    // TLC pending reward will remain at zero, because a week (epoch length) has not passed.
    assertEq(tlc.pendingReward(0, type(uint256).max, ALICE), 0 ether);
    assertEq(tlc.pendingReward(0, type(uint256).max, ALICE), 0 ether);

    // Forward to the end of the week
    vm.warp(block.timestamp + 4 days);
    // timePast = 60 * 60 * 24 * 7 = 604800
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Alice's share = 1,000,000 * 1e30
    // totalShare = 1,400,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (604800 / 31536000) * 100 * 1e18 * ((1000000 * 1e30)/(1400000 * 1e30))
    //               = 1.369863013698000000
    assertEq(ethMarketRewarder.pendingReward(ALICE), 1.369863013698000000 ether);
    // timePast = 60 * 60 * 24 * 7 = 604800
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Bob's share = 400,000 * 1e30
    // totalShare = 1,400,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (604800 / 31536000) * 100 * 1e18 * ((400000 * 1e30)/(1400000 * 1e30))
    //               = 0.547945205479200000
    assertEq(ethMarketRewarder.pendingReward(BOB), 0.547945205479200000 ether);
    // Alice's TLC pending reward
    // = Alice Share / Total Share * Total Reward
    // = 1,000,000 * 300 / 1,400,000 = 214.285714285714285714
    assertEq(tlc.pendingReward(0, type(uint256).max, ALICE), 214.285714285714285714 ether);
    // Bob's TLC pending reward
    // = Alice Share / Total Share * Total Reward
    // = 400,000 * 300 / 1,400,000 = 85.714285714285714285
    assertEq(tlc.pendingReward(0, type(uint256).max, BOB), 85.714285714285714285 ether);

    // Start of a new epoch (new week)
    // Alice trade for $700,000, but Bob did nothing
    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 700_000 * 1e30, address(0), 0);

    // Forward 1 day
    vm.warp(block.timestamp + 1 days);

    // Feed 144 TLC reward for this week
    // This feed happened 1 day into the new week
    rewardToken.mint(address(this), 144 ether);
    rewardToken.approve(address(tlc), 144 ether);
    tlc.feedReward(tlc.getCurrentEpochTimestamp(), 144 ether);

    // Forward to the next week
    vm.warp(block.timestamp + 7 days);
    // timePast = 60 * 60 * 24 * 8 = 691200
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Alice's share = 300,000 * 1e30
    // totalShare = 700,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare) + previousReward
    //               = (691200 / 31536000) * 100 * 1e18 * ((300000 * 1e30)/(700000 * 1e30)) + 1369863013698000000
    //               = 2.309197651662600000
    assertEq(ethMarketRewarder.pendingReward(ALICE), 2.309197651662600000 ether);
    // timePast = 60 * 60 * 24 * 7 = 691200
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Bob's share = 400,000 * 1e30
    // totalShare = 700,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (691200 / 31536000) * 100 * 1e18 * ((400000 * 1e30)/(700000 * 1e30)) + 547945205479200000
    //               = 1.800391389432000000
    assertEq(ethMarketRewarder.pendingReward(BOB), 1.800391389432000000 ether);
    // Alice's TLC pending reward
    // = Alice Share / Total Share * Total Reward
    // = 700,000 * 144 / 700,000 = 144
    // Include last week reward = 214.28571428571428 + 144 = 358.285714285714285713
    assertEq(tlc.pendingReward(0, type(uint256).max, ALICE), 358.285714285714285713 ether);
    // Bob's TLC pending reward should remain the same as Bob did not make any new trade this week.
    assertEq(tlc.pendingReward(0, type(uint256).max, BOB), 85.714285714285714285 ether);

    // Claim trading staking reward
    address[] memory rewarders = new address[](1);
    rewarders[0] = address(ethMarketRewarder);

    // Alice should receive 2.309197651662600000 reward token
    uint256 rewardBalanceBeforeAlice = rewardToken.balanceOf(ALICE);
    vm.prank(ALICE);
    tradingStaking.harvest(rewarders);
    uint256 rewardBalanceAfterAlice = rewardToken.balanceOf(ALICE);
    assertEq(rewardBalanceAfterAlice - rewardBalanceBeforeAlice, 2.309197651662600000 ether);

    // Bob should receive 2.309197651662600000 reward token
    uint256 rewardBalanceBeforeBob = rewardToken.balanceOf(BOB);
    vm.prank(BOB);
    tradingStaking.harvest(rewarders);
    uint256 rewardBalanceAfterBob = rewardToken.balanceOf(BOB);
    assertEq(rewardBalanceAfterBob - rewardBalanceBeforeBob, 1.800391389432000000 ether);

    // Claim TLC Reward
    // Alice should receive 358.285714285714285713 reward token
    assertEq(tlc.balanceOf(0, ALICE), 1_000_000 ether);
    assertEq(tlc.balanceOf(1 weeks, ALICE), 700_000 ether);
    rewardBalanceBeforeAlice = rewardToken.balanceOf(ALICE);
    tlc.claimReward(0, type(uint256).max, ALICE);
    rewardBalanceAfterAlice = rewardToken.balanceOf(ALICE);
    assertEq(rewardBalanceAfterAlice - rewardBalanceBeforeAlice, 358.285714285714285713 ether);
    assertEq(tlc.balanceOf(0, ALICE), 0);
    assertEq(tlc.balanceOf(1 weeks, ALICE), 0);
    // Bob should receive 85.714285714285714285 reward token
    assertEq(tlc.balanceOf(0, BOB), 400_000 ether);
    assertEq(tlc.balanceOf(1 weeks, BOB), 0 ether);
    rewardBalanceBeforeBob = rewardToken.balanceOf(BOB);
    tlc.claimReward(0, type(uint256).max, BOB);
    rewardBalanceAfterBob = rewardToken.balanceOf(BOB);
    assertEq(rewardBalanceAfterBob - rewardBalanceBeforeBob, 85.714285714285714285 ether);
    assertEq(tlc.balanceOf(0, BOB), 0 ether);
    assertEq(tlc.balanceOf(1 weeks, BOB), 0 ether);
  }
}
