// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginService_Base } from "./CrossMarginService_Base.t.sol";

contract CrossMarginService_Initialization is CrossMarginService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  function testRevert_setConfigStorage() external {
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_InvalidAddress()")
    );
    crossMarginService.setConfigStorage(address(0));
  }

  function testRevert_setVaultStorage() external {
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_InvalidAddress()")
    );
    crossMarginService.setVaultStorage(address(0));
  }

  function testRevert_setCalculator() external {
    vm.expectRevert(
      abi.encodeWithSignature("ICrossMarginService_InvalidAddress()")
    );
    crossMarginService.setCalculator(address(0));
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_crossMarginService_initializdStates() external {
    assertEq(crossMarginService.configStorage(), address(configStorage));
    assertEq(crossMarginService.vaultStorage(), address(vaultStorage));
    assertEq(crossMarginService.calculator(), address(mockCalculator));
  }

  function testCorrectness_crossMarginService_setConfigStorage() external {
    assertEq(crossMarginService.configStorage(), address(configStorage));
    crossMarginService.setConfigStorage(address(1));
    assertEq(crossMarginService.configStorage(), address(1));
  }

  function testCorrectness_crossMarginService_setVaultStorage() external {
    assertEq(crossMarginService.vaultStorage(), address(vaultStorage));
    crossMarginService.setVaultStorage(address(1));
    assertEq(crossMarginService.vaultStorage(), address(1));
  }

  function testCorrectness_crossMarginService_setCalculator() external {
    assertEq(crossMarginService.calculator(), address(mockCalculator));
    crossMarginService.setCalculator(address(1));
    assertEq(crossMarginService.calculator(), address(1));
  }
}
