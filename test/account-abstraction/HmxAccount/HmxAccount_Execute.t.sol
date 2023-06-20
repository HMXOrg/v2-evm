// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { HmxAccount_Base } from "@hmx-test/account-abstraction/HmxAccount/HmxAccount_Base.t.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract HmxAccount_ExecuteTest is HmxAccount_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenOwnerCallExecute() external {
    // Setup mock states so execute not fail
    MockErc20 token = new MockErc20("some", "some", 18);
    token.mint(address(this), 1 ether);
    token.approve(address(hmxAccount), 1 ether);

    hmxAccount.execute(
      address(token),
      0,
      abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether)
    );
  }
}
