// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

abstract contract StorageDeployment {
  function deployConfigStorage() internal returns (ConfigStorage) {
    return new ConfigStorage();
  }

  function deployPerpStorage() internal returns (PerpStorage) {
    return new PerpStorage();
  }

  function deployVaultStorage() internal returns (VaultStorage) {
    return new VaultStorage();
  }
}
