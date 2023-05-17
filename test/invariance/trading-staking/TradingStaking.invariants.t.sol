// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest, MockErc20 } from "@hmx-test/base/BaseTest.sol";
import { Test } from "forge-std/Test.sol";
import { InvariantTest } from "forge-std/InvariantTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { console2 } from "forge-std/console2.sol";
import { TradeService_Base } from "@hmx-test/services/trade/TradeService_Base.t.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { ITradeServiceHook } from "@hmx/services/interfaces/ITradeServiceHook.sol";
import { MintableTokenInterface } from "@hmx/staking/interfaces/MintableTokenInterface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITLCStaking } from "@hmx/staking/interfaces/ITLCStaking.sol";
import { IEpochRewarder } from "@hmx/staking/interfaces/IEpochRewarder.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";

contract TradingStakingInvariants is InvariantTest, TradeService_Base {
  MockErc20 internal rewardToken;
  MockErc20 internal tlc;
  ITradingStaking internal tradingStaking;
  ITradeServiceHook internal tradingStakingHook;
  ITradeServiceHook internal tlcHook;
  IRewarder internal ethMarketRewarder;
  ITLCStaking internal tlcStaking;
  IEpochRewarder internal tlcRewarder;

  function setUp() public virtual override {
    super.setUp();

    rewardToken = new MockErc20("Reward Token", "RWD", 18);
    tradingStaking = Deployer.deployTradingStaking(address(proxyAdmin));
    tradingStakingHook = Deployer.deployTradingStakingHook(
      address(proxyAdmin),
      address(tradingStaking),
      address(tradeService)
    );
    tlc = new MockErc20("Trader Loyalty Credit", "TLC", 18);
    tlcStaking = Deployer.deployTLCStaking(address(proxyAdmin), address(tlc));
    tlcHook = Deployer.deployTLCHook(address(proxyAdmin), address(tradeService), address(tlc), address(tlcStaking));

    address[] memory _hooks = new address[](2);
    _hooks[0] = address(tradingStakingHook);
    _hooks[1] = address(tlcHook);
    configStorage.setTradeServiceHooks(_hooks);

    ethMarketRewarder = Deployer.deployFeedableRewarder(
      address(proxyAdmin),
      "Gov",
      address(rewardToken),
      address(tradingStaking)
    );
    tlcRewarder = Deployer.deployEpochFeedableRewarder(
      address(proxyAdmin),
      "TLC",
      address(rewardToken),
      address(tlcStaking)
    );

    uint256[] memory _marketIndices = new uint256[](1);
    _marketIndices[0] = ethMarketIndex;
    tradingStaking.addRewarder(address(ethMarketRewarder), _marketIndices);
    tradingStaking.setWhitelistedCaller(address(tradingStakingHook));

    tlcStaking.addRewarder(address(tlcRewarder));
    tlcStaking.setWhitelistedCaller(address(tlcHook));

    rewardToken.mint(address(this), 100 ether);
    rewardToken.approve(address(ethMarketRewarder), 100 ether);
    ethMarketRewarder.feed(100 ether, 365 days);
  }

  /**
   * Invariances
   */

  /**
   * Internal functions
   */
}
