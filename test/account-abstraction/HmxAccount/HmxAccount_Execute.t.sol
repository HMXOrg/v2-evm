// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { HmxAccount_Base } from "@hmx-test/account-abstraction/HmxAccount/HmxAccount_Base.t.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract HmxAccount_ExecuteTest is HmxAccount_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenTryToExecuteNotAllowedDest() external {
    vm.expectRevert("destination not allowed");
    hmxAccount.execute(address(this), 0, "");
  }

  function testCorrectness_WhenCallToAllowedDest() external {
    // Setup mock states so execute not fail
    MockErc20 token = new MockErc20("some", "some", 18);
    token.mint(address(this), 1 ether);
    token.approve(address(hmxAccount), 1 ether);

    // Allow token to be called by HmxAccount
    hmxAccountFactory.setIsAllowedDest(address(token), true);

    hmxAccount.execute(
      address(token),
      0,
      abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether)
    );
  }
}
