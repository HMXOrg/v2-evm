// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

contract CrossMarginHandler_Initialization is CrossMarginHandler_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  function testRevert_setConfigStorage() external {
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginHandler_InvalidAddress()")
    );
    crossMarginHandler.setConfigStorage(address(0));
  }

  function testRevert_setCrossMarginService() external {
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginHandler_InvalidAddress()")
    );
    crossMarginHandler.setCrossMarginService(address(0));
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_crossMarginHandler_initializdStates() external {
    assertEq(crossMarginHandler.configStorage(), address(configStorage));
    assertEq(
      crossMarginHandler.crossMarginService(),
      address(crossMarginService)
    );
  }

  function testCorrectness_crossMarginHandler_setConfigStorage() external {
    assertEq(crossMarginHandler.configStorage(), address(configStorage));
    crossMarginHandler.setConfigStorage(address(1));
    assertEq(crossMarginHandler.configStorage(), address(1));
  }

  function testCorrectness_crossMarginHandler_setCrossMarginService() external {
    assertEq(
      crossMarginHandler.crossMarginService(),
      address(crossMarginService)
    );
    crossMarginHandler.setCrossMarginService(address(1));
    assertEq(crossMarginHandler.crossMarginService(), address(1));
  }
}
