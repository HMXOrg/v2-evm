// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { FeedableRewarder } from "@hmx/staking/FeedableRewarder.sol";

contract DeployTradingStakingFeedableRewarder is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address esHMXAddress = getJsonAddress(".tokens.esHmx");
    address tradingStakingAddress = getJsonAddress(".staking.trading");
    address ethusdRewarderAddress = address(new FeedableRewarder("ETHUSD", esHMXAddress, tradingStakingAddress));
    address btcusdRewarderAddress = address(new FeedableRewarder("BTCUSD", esHMXAddress, tradingStakingAddress));
    address applusdRewarderAddress = address(new FeedableRewarder("APPLUSD", esHMXAddress, tradingStakingAddress));
    address jpyusdRewarderAddress = address(new FeedableRewarder("JPYUSD", esHMXAddress, tradingStakingAddress));
    vm.stopBroadcast();

    updateJson(".rewarders.tradingStaking.ETHUSD", ethusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.BTCUSD", btcusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.AAPLUSD", applusdRewarderAddress);
    updateJson(".rewarders.tradingStaking.JPYUSD", jpyusdRewarderAddress);
  }
}
