// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { HmxAccount_Base } from "@hmx-test/account-abstraction/HmxAccount/HmxAccount_Base.t.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

contract HmxAccount_BatchExecuteTest is HmxAccount_Base {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenTryToExecuteNotAllowedDest() external {
    address[] memory dests = new address[](1);
    dests[0] = address(this);

    bytes[] memory datas = new bytes[](1);
    datas[0] = "";

    vm.expectRevert("destination not allowed");
    hmxAccount.executeBatch(dests, datas);
  }

  function testRevert_WhenSomeNotAllowedDest() external {
    // Setup mock states so execute not fail
    MockErc20 token = new MockErc20("some", "some", 18);
    token.mint(address(this), 2 ether);
    token.approve(address(hmxAccount), 2 ether);

    // Allow token to be called by HmxAccount
    hmxAccountFactory.setIsAllowedDest(address(token), true);

    address[] memory dests = new address[](2);
    dests[0] = address(token);
    dests[1] = address(this);

    bytes[] memory datas = new bytes[](2);
    datas[0] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);
    datas[1] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);

    vm.expectRevert("destination not allowed");
    hmxAccount.executeBatch(dests, datas);
  }

  function testCorrectness_WhenCallToAllowedDest() external {
    // Setup mock states so execute not fail
    MockErc20 token = new MockErc20("some", "some", 18);
    token.mint(address(this), 2 ether);
    token.approve(address(hmxAccount), 2 ether);

    // Allow token to be called by HmxAccount
    hmxAccountFactory.setIsAllowedDest(address(token), true);

    address[] memory dests = new address[](2);
    dests[0] = address(token);
    dests[1] = address(token);

    bytes[] memory datas = new bytes[](2);
    datas[0] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);
    datas[1] = abi.encodeWithSelector(token.transferFrom.selector, address(this), address(hmxAccount), 1 ether);

    hmxAccount.executeBatch(dests, datas);
  }
}
