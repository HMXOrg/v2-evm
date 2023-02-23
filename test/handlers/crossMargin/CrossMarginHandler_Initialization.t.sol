// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { CrossMarginHandler_Base, CrossMarginService } from "./CrossMarginHandler_Base.t.sol";

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
    CrossMarginService newCrossMarginService = deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(calculator)
    );
    assertEq(crossMarginHandler.crossMarginService(), address(crossMarginService));
    crossMarginHandler.setCrossMarginService(address(newCrossMarginService));
    assertEq(crossMarginHandler.crossMarginService(), address(newCrossMarginService));
  }

  function testCorrectness_crossMarginHandler_setPyth() external {
    DeployReturnVars memory deployed = deployPerp88v2();
    crossMarginHandler.setPyth(address(deployed.pythAdapter.pyth()));
    assertEq(crossMarginHandler.pyth(), address(deployed.pythAdapter.pyth()));
  }
}
