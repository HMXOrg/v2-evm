// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { TradingStaking } from "@hmx/staking/TradingStaking.sol";

contract DeployHMXToken is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address tradingStakingAddress = address(new TradingStaking());
    vm.stopBroadcast();

    updateJson(".staking.trading", tradingStakingAddress);
  }
}
