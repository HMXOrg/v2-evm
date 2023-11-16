// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { IDistributeSTIPARBStrategy } from "@hmx/strategies/interfaces/IDistributeSTIPARBStrategy.sol";
import { IERC20ApproveStrategy } from "@hmx/strategies/interfaces/IERC20ApproveStrategy.sol";

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

    IERC20ApproveStrategy approveStrat = Deployer.deployERC20ApproveStrategy(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.vaultStorage)
    );
    IDistributeSTIPARBStrategy distributeStrat = Deployer.deployDistributeSTIPARBStrategy(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.vaultStorage),
      address(arbRewarderForHlp),
      address(ForkEnv.arb),
      500, // 5% dev fee
      0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872,
      address(approveStrat)
    );

    approveStrat.setWhitelistedExecutor(address(distributeStrat), true);
    distributeStrat.setWhitelistedExecutor(address(this), true);

    vm.startPrank(ForkEnv.vaultStorage.owner());
    vaultStorage.setStrategyAllowance(address(ForkEnv.arb), address(approveStrat), address(ForkEnv.arb));
    vaultStorage.setStrategyFunctionSigAllowance(
      address(ForkEnv.arb),
      address(approveStrat),
      IERC20Upgradeable.approve.selector
    );
    vaultStorage.setStrategyAllowance(address(ForkEnv.arb), address(distributeStrat), address(arbRewarderForHlp));
    vaultStorage.setStrategyFunctionSigAllowance(
      address(ForkEnv.arb),
      address(distributeStrat),
      IRewarder.feedWithExpiredAt.selector
    );
    vaultStorage.setServiceExecutors(address(distributeStrat), true);
    vm.stopPrank();

    uint256 aumBefore = ForkEnv.calculator.getAUME30(false);

    // console2.log(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
    distributeStrat.execute(30289413075306806328952, block.timestamp + 7 days);

    // distributedAmount = (30289413075306806328952 * (10000 - 500)) / 10000
    // distributedAmount = 28774942421541466012505
    assertEq(arb.balanceOf(address(arbRewarderForHlp)), 28774942421541466012505);

    assertEq(aumBefore, ForkEnv.calculator.getAUME30(false));
  }
}
