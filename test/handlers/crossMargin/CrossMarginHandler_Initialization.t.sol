// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { CrossMarginHandler_Base } from "./CrossMarginHandler_Base.t.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

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
    ICrossMarginService newCrossMarginService = Deployer.deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(calculator)
    );
    assertEq(crossMarginHandler.crossMarginService(), address(crossMarginService));
    crossMarginHandler.setCrossMarginService(address(newCrossMarginService));
    assertEq(crossMarginHandler.crossMarginService(), address(newCrossMarginService));
  }

  function testCorrectness_crossMarginHandler_setPyth() external {
    crossMarginHandler.setPyth(address(pythAdapter.pyth()));
    assertEq(crossMarginHandler.pyth(), address(pythAdapter.pyth()));
  }
}
