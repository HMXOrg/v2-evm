// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { HmxAccountFactory_Base } from "@hmx-test/account-abstraction/HmxAccountFactory/HmxAccountFactory_Base.t.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

contract HmxAccountFactory_GetAdddressTest is HmxAccountFactory_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenGetAddressBeforeActualHmxAccountCreated() external {
    address owner = makeAddr("some user");
    uint256 salt = 0;

    // Get the address of the account
    address accountAddress = hmxAccountFactory.getAddress(owner, salt);

    // Create an account
    HmxAccount account = hmxAccountFactory.createAccount(owner, salt);

    assertEq(address(account), accountAddress, "should have the same address");
  }
}
