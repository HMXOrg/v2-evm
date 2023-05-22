// SPDX-License-Identifier: MIT
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
