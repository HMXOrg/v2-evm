// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { TradingStakingHook } from "@hmx/staking/TradingStakingHook.sol";

contract DeployTradingStakingHook is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address tradingStakingAddress = getJsonAddress(".staking.trading");
    address tradingServiceAddress = getJsonAddress(".services.trade");

    address tradingStakingHookAddress = address(new TradingStakingHook(tradingStakingAddress, tradingServiceAddress));
    vm.stopBroadcast();

    updateJson(".hooks.tradingStaking", tradingStakingHookAddress);
  }
}
