// // SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { HmxAccountFactory_Base } from "@hmx-test/account-abstraction/HmxAccountFactory/HmxAccountFactory_Base.t.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

contract HmxAccountFactory_IsAllowedDestTest is HmxAccountFactory_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenNotOwnerCallSetIsAllowedDest() external {
    address someRandomUser = makeAddr("some random user");

    vm.prank(someRandomUser);
    vm.expectRevert("Ownable: caller is not the owner");
    hmxAccountFactory.setIsAllowedDest(someRandomUser, true);
  }

  function testCorrectness_WhenOwnerCallSetIsAllowedDest() external {
    address someDest = makeAddr("some dest");
    hmxAccountFactory.setIsAllowedDest(someDest, true);

    assertTrue(hmxAccountFactory.isAllowedDest(someDest), "should be allowed dest");

    hmxAccountFactory.setIsAllowedDest(someDest, false);
    assertFalse(hmxAccountFactory.isAllowedDest(someDest), "should not be allowed dest");
  }
}
