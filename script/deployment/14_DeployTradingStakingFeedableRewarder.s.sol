// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { FeedableRewarder } from "@hmx/staking/FeedableRewarder.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployTradingStakingFeedableRewarder is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    address esHMXAddress = getJsonAddress(".tokens.esHmx");
    address tradingStakingAddress = getJsonAddress(".staking.trading");
    address ethusdRewarderAddress = address(
      Deployer.deployFeedableRewarder(proxyAdmin, "ETHUSD", esHMXAddress, tradingStakingAddress)
    );
    address btcusdRewarderAddress = address(
      Deployer.deployFeedableRewarder(proxyAdmin, "BTCUSD", esHMXAddress, tradingStakingAddress)
    );
    address applusdRewarderAddress = address(
      Deployer.deployFeedableRewarder(proxyAdmin, "APPLUSD", esHMXAddress, tradingStakingAddress)
    );
    address jpyusdRewarderAddress = address(
      Deployer.deployFeedableRewarder(proxyAdmin, "JPYUSD", esHMXAddress, tradingStakingAddress)
    );
    vm.stopBroadcast();

    updateJson(".rewarders.tradingStaking.ETHUSD", ethusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.BTCUSD", btcusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.AAPLUSD", applusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.JPYUSD", jpyusdRewarderAddress);
  }
}
