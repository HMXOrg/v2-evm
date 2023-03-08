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
import { Deployer } from "@hmx-test/libs/Deployer.sol";

// @todo - add test desciption + use position tester help to check
// @todo - rename test case

contract TradeService_Hooks is TradeService_Base {
  MockErc20 internal rewardToken;
  ITradingStaking internal tradingStaking;
  ITradeServiceHook internal tradingStakingHook;
  IRewarder internal ethMarketRewarder;

  function setUp() public virtual override {
    super.setUp();

    rewardToken = new MockErc20("Reward Token", "RWD", 18);
    tradingStaking = Deployer.deployTradingStaking();
    tradingStakingHook = Deployer.deployTradingStakingHook(address(tradingStaking), address(tradeService));

    address[] memory _hooks = new address[](1);
    _hooks[0] = address(tradingStakingHook);
    configStorage.setTradeServiceHooks(_hooks);

    ethMarketRewarder = Deployer.deployFeedableRewarder("Gov", address(rewardToken), address(tradingStaking));

    uint256[] memory _marketIndices = new uint256[](1);
    _marketIndices[0] = ethMarketIndex;
    tradingStaking.addRewarder(address(ethMarketRewarder), _marketIndices);
    tradingStaking.setWhitelistedCaller(address(tradingStakingHook));

    rewardToken.mint(address(this), 100 ether);
    rewardToken.approve(address(ethMarketRewarder), 100 ether);
    ethMarketRewarder.feed(100 ether, 365 days);
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
    tradingStakingHook.onIncreasePosition(ALICE, 0, ethMarketIndex, uint256(sizeDelta));
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

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 300 * 1e30, address(wbtc), price);
    assertEq(tradingStaking.getUserTokenAmount(ethMarketIndex, ALICE), uint256(sizeDelta - 300 * 1e30));
  }

  function testCorrectness_pendingRewardToken() external {
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

    vm.warp(block.timestamp + 3 days);
    // timePast = 60 * 60 * 24 * 3 = 259200
    // feedDuration = 60 * 60 * 24 * 365 = 31536000
    // Alice's share = 1,000,000 * 1e30
    // totalShare = 1,000,000 * 1e30
    // totalReward = 100 * 1e18
    // pendingReward = (timePast / feedDuration) * totalReward * (aliceShare / totalShare)
    //               = (259200 / 31536000) * 100 * 1e18 * ((1,000,000 * 1e30)/(1,000,000 * 1e30))
    //               = 0.821917808219000000
    assertEq(ethMarketRewarder.pendingReward(ALICE), 0.821917808219000000 ether);
  }
}
