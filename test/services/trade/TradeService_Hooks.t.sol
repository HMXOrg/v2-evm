// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockErc20, TradingStaking, TradingStakingHook } from "../../base/BaseTest.sol";
import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { GlobalMarketTester } from "../../testers/GlobalMarketTester.sol";

import { ITradeService } from "../../../src/services/interfaces/ITradeService.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

// @todo - add test desciption + use position tester help to check
// @todo - rename test case

contract TradeService_Hooks is TradeService_Base {
  MockErc20 internal rewardToken;
  TradingStaking internal tradingStaking;
  TradingStakingHook internal tradingStakingHook;

  function setUp() public virtual override {
    super.setUp();

    rewardToken = deployMockErc20("Reward Token", "RWD", 18);
    tradingStaking = deployTradingStaking(address(rewardToken), 1 ether);
    tradingStakingHook = deployTradingStakingHook(address(tradingStaking), address(tradeService));

    address[] memory _hooks = new address[](1);
    _hooks[0] = address(tradingStakingHook);
    configStorage.setTradeServiceHooks(_hooks);

    tradingStaking.addPool(2, ethMarketIndex, address(0), true);
    tradingStaking.setWhitelistedCaller(address(tradingStakingHook));
  }

  function testRevert_WrongPool() external {
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
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

    vm.warp(100);
    vm.expectRevert(abi.encodeWithSignature("ITradingStaking_WrongPool()"));
    tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);
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
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

    vm.warp(100);
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);

    (uint256 _amount, int256 _rewardDebt) = tradingStaking.userInfo(0, ALICE);
    assertEq(_amount, uint256(sizeDelta));
    assertEq(_rewardDebt, 0);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 300 * 1e30, address(wbtc), price);
    (_amount, _rewardDebt) = tradingStaking.userInfo(0, ALICE);
    assertEq(_amount, uint256(sizeDelta - 300 * 1e30));
    assertEq(_rewardDebt, 0);
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
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

    vm.warp(100);
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);

    (uint256 _amount, int256 _rewardDebt) = tradingStaking.userInfo(0, ALICE);
    assertEq(_amount, uint256(sizeDelta));
    assertEq(_rewardDebt, 0);

    tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 300 * 1e30, address(wbtc), price);
    (_amount, _rewardDebt) = tradingStaking.userInfo(0, ALICE);
    assertEq(_amount, uint256(sizeDelta - 300 * 1e30));
    assertEq(_rewardDebt, 0);
  }
}
