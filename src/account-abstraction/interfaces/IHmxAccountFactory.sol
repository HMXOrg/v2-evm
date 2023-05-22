// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

interface IHmxAccountFactory {
  function upgrade(UUPSUpgradeable[] calldata _accounts, address _newAccountImplementation) external;

  function createAccount(address _owner, uint256 salt) external returns (HmxAccount ret);

  function getAddress(address _owner, uint256 salt) external view returns (address);
}
