// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { TradingStakingHook } from "@hmx/staking/TradingStakingHook.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployTradingStakingHook is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    vm.startBroadcast(deployerPrivateKey);
    address tradingStakingAddress = getJsonAddress(".staking.trading");
    address tradingServiceAddress = getJsonAddress(".services.trade");

    address tradingStakingHookAddress = address(
      Deployer.deployTradingStakingHook(proxyAdmin, tradingStakingAddress, tradingServiceAddress)
    );
    vm.stopBroadcast();

    updateJson(".hooks.tradingStaking", tradingStakingHookAddress);
  }
}
