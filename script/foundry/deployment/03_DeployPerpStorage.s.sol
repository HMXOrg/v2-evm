// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployPerpStorage is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    vm.startBroadcast(deployerPrivateKey);

    address perpStorageAddress = address(Deployer.deployPerpStorage(address(proxyAdmin)));

    vm.stopBroadcast();

    updateJson(".storages.perp", perpStorageAddress);
  }
}
