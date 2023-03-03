// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigStorage } from "../../src/storages/ConfigStorage.sol";
import { VaultStorage } from "../../src/storages/VaultStorage.sol";

abstract contract StorageDeployment {
  function deployConfigStorage() internal returns (ConfigStorage) {
    return new ConfigStorage();
  }

  function deployVaultStorage() internal returns (VaultStorage) {
    return new VaultStorage();
  }
}
