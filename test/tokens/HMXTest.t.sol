// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { HMX } from "@hmx/tokens/HMX.sol";

contract HMXTest is BaseTest {
  HMX internal hmx;

  function setUp() external {
    hmx = new HMX(true);
  }

  function testCorrectness_init() external {
    assertEq(hmx.name(), "HMX");
    assertEq(hmx.symbol(), "HMX");
  }

  function testCorrectness_setMinter() external {
    assertFalse(hmx.isMinter(ALICE));
    hmx.setMinter(ALICE, true);
    assertTrue(hmx.isMinter(ALICE));
  }

  function testCorrectness_mint() external {
    hmx.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    hmx.mint(BOB, 88 ether);
    assertEq(hmx.balanceOf(BOB), 88 ether);
    vm.stopPrank();
  }

  function testRevert_mint() external {
    vm.expectRevert(abi.encodeWithSignature("BaseMintableToken_NotMinter()"));
    hmx.mint(BOB, 88 ether);
  }

  function testRevert_burn() external {
    vm.expectRevert(abi.encodeWithSignature("BaseMintableToken_NotMinter()"));
    hmx.burn(BOB, 88 ether);
  }
}
