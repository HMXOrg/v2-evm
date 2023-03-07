// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IConfigStorage } from "../../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../../storages/interfaces/IVaultStorage.sol";

interface IPLPv2 {
  /**
   * ERRORS
   */
  error IPLPv2_onlyMinter();

  function setMinter(address minter, bool isMinter) external;

  function mint(address to, uint256 amount) external;

  function burn(address from, uint256 amount) external;
}
