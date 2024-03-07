// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Erc4626Dexter_BaseTest } from "./Erc4626Dexter_BaseTest.t.sol";

contract Erc4626Dexter_RunTest is Erc4626Dexter_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenWrongTokenOut() external {
    vm.expectRevert(abi.encodeWithSignature("Erc4626Dexter_NotSupported()"));
    erc4626Dexter.run(address(ybusdb), address(weth), 1e18);
  }

  function testRevert_WhenBadTokenIn() external {
    vm.expectRevert(abi.encodeWithSignature("Erc4626Dexter_NotSupported()"));
    erc4626Dexter.run(address(weth), address(ybusdb), 1e18);
  }

  function testRevert_WhenNeitherTokensSupported() external {
    vm.expectRevert(abi.encodeWithSignature("Erc4626Dexter_NotSupported()"));
    erc4626Dexter.run(address(weth), address(weth), 1e18);
  }

  function testCorrectness_WhenErc4626ToUnderlying() external {
    dealyb(payable(address(ybeth)), address(erc4626Dexter), 1 ether);
    erc4626Dexter.run(address(ybeth), address(weth), 1 ether);
    assertEq(weth.balanceOf(address(this)), 1 ether);
  }

  function testCorrectness_WhenUnderlyingToErc4626() external {
    usdb.mint(address(erc4626Dexter), 1 ether);
    erc4626Dexter.run(address(usdb), address(ybusdb), 1 ether);
    assertEq(ybusdb.balanceOf(address(this)), 1 ether);
  }
}
