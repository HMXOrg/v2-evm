// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract SetTradingHooks is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ConfigStorage configStorage = ConfigStorage(getJsonAddress(".storages.config"));
    address[] memory _newHooks = new address[](1);
    _newHooks[0] = getJsonAddress(".hooks.tradingStaking");
    configStorage.setTradeServiceHooks(_newHooks);
    vm.stopBroadcast();
  }
}
