// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { HmxAccountFactory } from "@hmx/account-abstraction/HmxAccountFactory.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

contract HmxAccount_Base is BaseTest {
  HmxAccountFactory public hmxAccountFactory;
  HmxAccount public hmxAccount;

  function setUp() public virtual {
    hmxAccountFactory = HmxAccountFactory(address(Deployer.deployHmxAccountFactory(address(this))));
    hmxAccount = hmxAccountFactory.createAccount(address(this), 0);
  }
}
