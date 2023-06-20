// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { HmxAccount_Base } from "@hmx-test/account-abstraction/HmxAccount/HmxAccount_Base.t.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract HmxAccount_BatchExecuteTest is HmxAccount_Base {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenOwnerCallBatchExecute() external {
    // Setup mock states so execute not fail
    MockErc20 token = new MockErc20("some", "some", 18);
    token.mint(address(this), 2 ether);
    token.approve(address(hmxAccount), 2 ether);

    address[] memory dests = new address[](2);
    dests[0] = address(token);
    dests[1] = address(token);

    bytes[] memory datas = new bytes[](2);
    datas[0] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);
    datas[1] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);

    hmxAccount.executeBatch(dests, datas);
  }
}
