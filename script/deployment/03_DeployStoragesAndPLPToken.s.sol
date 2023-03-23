// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";

contract DeployStoragesAndPLPToken is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address configStorageAddress = address(new ConfigStorage());
    address perpStorageAddress = address(new PerpStorage());
    address vaultStorageAddress = address(new VaultStorage());
    address plpAddress = address(new PLPv2());

    vm.stopBroadcast();

    updateJson(".storages.config", configStorageAddress);
    updateJson(".storages.perp", perpStorageAddress);
    updateJson(".storages.vault", vaultStorageAddress);
    updateJson(".tokens.plp", plpAddress);
  }
}
