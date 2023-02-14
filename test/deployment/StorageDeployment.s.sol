// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigStorage } from "../../src/storages/ConfigStorage.sol";
import { PerpStorage } from "../../src/storages/PerpStorage.sol";
import { VaultStorage } from "../../src/storages/VaultStorage.sol";

abstract contract StorageDeployment {
  function deployConfigStorage() internal returns (address) {
    return address(new ConfigStorage());
  }

  function deployPerpStorage() internal returns (address) {
    return address(new PerpStorage());
  }

  function deployVaultStorage() internal returns (address) {
    return address(new VaultStorage());
  }
}
