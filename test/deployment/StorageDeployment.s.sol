// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { VaultStorage } from "../../src/storages/VaultStorage.sol";

abstract contract StorageDeployment {
  function deployVaultStorage() internal returns (VaultStorage) {
    return new VaultStorage();
  }
}
