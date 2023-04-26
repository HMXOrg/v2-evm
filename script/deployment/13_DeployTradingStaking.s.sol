// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { TradingStaking } from "@hmx/staking/TradingStaking.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployTradingStaking is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    vm.startBroadcast(deployerPrivateKey);
    address tradingStakingAddress = address(Deployer.deployTradingStaking(proxyAdmin));
    vm.stopBroadcast();

    updateJson(".staking.trading", tradingStakingAddress);
  }
}
