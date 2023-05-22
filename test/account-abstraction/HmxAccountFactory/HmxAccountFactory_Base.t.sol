// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { HmxAccountFactory } from "@hmx/account-abstraction/HmxAccountFactory.sol";

contract HmxAccountFactory_Base is BaseTest {
  HmxAccountFactory public hmxAccountFactory;

  function setUp() public virtual {
    hmxAccountFactory = HmxAccountFactory(address(Deployer.deployHmxAccountFactory(address(this))));
  }
}
