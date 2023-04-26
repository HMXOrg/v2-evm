// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployConfigStorage is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    address configStorageAddress = address(Deployer.deployConfigStorage(address(proxyAdmin)));
    address perpStorageAddress = address(Deployer.deployPerpStorage(address(proxyAdmin)));
    address vaultStorageAddress = address(Deployer.deployVaultStorage(address(proxyAdmin)));
    address plpAddress = address(Deployer.deployPLPv2(address(proxyAdmin)));

    vm.stopBroadcast();

    updateJson(".storages.config", configStorageAddress);
  }
}
