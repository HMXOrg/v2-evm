// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { HmxAccountFactory_Base } from "@hmx-test/account-abstraction/HmxAccountFactory/HmxAccountFactory_Base.t.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

contract HmxAccountFactory_CreateAccountTest is HmxAccountFactory_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenCreateAccount() external {
    address owner = makeAddr("some user");
    uint256 salt = 0;

    // Create an account
    HmxAccount account = hmxAccountFactory.createAccount(owner, salt);

    // Assert the account is created correctly
    // - The account's factory is HmxAccountFactory
    // - The account's owner is the owner
    assertEq(address(account.factory()), address(hmxAccountFactory));
    assertEq(account.owner(), owner);
  }
}
