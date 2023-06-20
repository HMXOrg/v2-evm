// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { Calculator_Base } from "./Calculator_Base.t.sol";

contract Calculator_Initialization is Calculator_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  // =========================================
  // | ------- Test Revert ----------------- |
  // =========================================

  function testRevert_setOracle() external {
    vm.expectRevert(abi.encodeWithSignature("ICalculator_InvalidAddress()"));
    calculator.setOracle(address(0));
  }

  function testRevert_setVaultStorage() external {
    vm.expectRevert(abi.encodeWithSignature("ICalculator_InvalidAddress()"));
    calculator.setVaultStorage(address(0));
  }

  function testRevert_setConfigStorage() external {
    vm.expectRevert(abi.encodeWithSignature("ICalculator_InvalidAddress()"));
    calculator.setConfigStorage(address(0));
  }

  function testRevert_setPerpStorage() external {
    vm.expectRevert(abi.encodeWithSignature("ICalculator_InvalidAddress()"));
    calculator.setPerpStorage(address(0));
  }

  // =========================================
  // | ------- Test Correctness ------------ |
  // =========================================

  function testCorrectness_calculator_initializdStates() external {
    assertEq(calculator.oracle(), address(mockOracle));
    assertEq(calculator.vaultStorage(), address(mockVaultStorage));
    assertEq(calculator.configStorage(), address(configStorage));
    assertEq(calculator.perpStorage(), address(mockPerpStorage));
  }

  function testCorrectness_calculator_setOracle() external {
    assertEq(calculator.oracle(), address(mockOracle));
    vm.expectRevert(); // revert in case sanity check
    calculator.setOracle(address(1));
  }

  function testCorrectness_calculator_setVaultStorage() external {
    assertEq(calculator.vaultStorage(), address(mockVaultStorage));
    vm.expectRevert(); // revert in case sanity check
    calculator.setVaultStorage(address(1));
  }

  function testCorrectness_calculator_setConfigStorage() external {
    assertEq(calculator.configStorage(), address(configStorage));
    vm.expectRevert(); // revert in case sanity check
    calculator.setConfigStorage(address(1));
  }

  function testCorrectness_calculator_setPerpStorage() external {
    assertEq(calculator.perpStorage(), address(mockPerpStorage));
    vm.expectRevert(); // revert in case sanity check
    calculator.setPerpStorage(address(1));
  }
}
