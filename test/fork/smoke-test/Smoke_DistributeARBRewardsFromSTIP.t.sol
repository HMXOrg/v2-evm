// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { console2 } from "forge-std/console2.sol";

contract Smoke_DistributeARBRewardsFromSTIP is ForkEnv {
  function distributeARBRewardsFromSTIP() external {
    IRewarder arbRewarderForHlp = Deployer.deployFeedableRewarder(
      address(ForkEnv.proxyAdmin),
      "HLP Staking ARB Rewards",
      address(ForkEnv.arb),
      address(ForkEnv.hlpStaking)
    );
    arbRewarderForHlp.setFeeder(address(ForkEnv.vaultStorage));

    address[] memory rewarders = new address[](1);
    rewarders[0] = address(ForkEnv.hlpStaking);
    vm.startPrank(ForkEnv.hlpStaking.owner());
    ForkEnv.hlpStaking.addRewarders(rewarders);
    vm.stopPrank();

    uint256 aumBefore = ForkEnv.calculator.getAUME30(false)

    vm.startPrank(ForkEnv.vaultStorage.owner());
    ForkEnv.vaultStorage.distributeARBRewardsFromSTIP(
      30289413075306806328952,
      address(arbRewarderForHlp),
      block.timestamp + 7 days
    );
    vm.stopPrank();

    assertEq(aumBefore, ForkEnv.calculator.getAUME30(false));
  }
}
