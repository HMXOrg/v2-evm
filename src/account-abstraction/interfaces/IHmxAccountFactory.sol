// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

interface IHmxAccountFactory {
  function upgrade(UUPSUpgradeable[] calldata _accounts, address _newAccountImplementation) external;

  function createAccount(address _owner, uint256 salt) external returns (HmxAccount ret);

  function getAddress(address _owner, uint256 salt) external view returns (address);
}
