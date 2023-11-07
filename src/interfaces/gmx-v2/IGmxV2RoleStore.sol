// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxV2RoleStore {
  function grantRole(address account, bytes32 role) external;
}
