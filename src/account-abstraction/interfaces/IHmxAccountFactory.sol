// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

interface IHmxAccountFactory {
  function isAllowedDest(address owner) external returns (bool);

  function ownerOf(address account) external returns (address);

  function setIsAllowedDest(address _dest, bool _isAllowed) external;

  function upgrade(UUPSUpgradeable[] calldata _accounts, address _newAccountImplementation) external;

  function createAccount(address _owner, uint256 salt) external returns (HmxAccount ret);

  function getAddress(address _owner, uint256 salt) external view returns (address);
}
