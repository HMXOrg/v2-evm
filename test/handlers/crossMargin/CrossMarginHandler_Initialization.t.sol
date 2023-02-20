// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

contract CrossMarginHandler_Initialization is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST REVERT
   */

  function testRevert_setCrossMarginService() external {
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_InvalidAddress()"));
    crossMarginHandler.setCrossMarginService(address(0));
  }

  function testRevert_setPyth() external {
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler_InvalidAddress()"));
    crossMarginHandler.setPyth(address(0));
  }

  /**
   * TEST CORRECTNESS
   */

  function testCorrectness_crossMarginHandler_setCrossMarginService() external {
    assertEq(crossMarginHandler.crossMarginService(), address(crossMarginService));
    crossMarginHandler.setCrossMarginService(address(1));
    assertEq(crossMarginHandler.crossMarginService(), address(1));
  }

  function testCorrectness_crossMarginHandler_setPyth() external {
    crossMarginHandler.setPyth(address(1));
    assertEq(crossMarginHandler.pyth(), address(1));
  }
}
