// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";
import { console } from "forge-std/console.sol";

contract MockPerpStorage is IPerpStorage {
  mapping(address => Position[]) public positions;

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setPositionBySubAccount(
    address _subAccount,
    Position memory _position
  ) external {
    positions[_subAccount].push(_position);
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getPositionBySubAccount(
    address _subAccount
  ) external view returns (Position[] memory traderPositions) {
    return positions[_subAccount];
  }
}
