// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { CrossMarginHandler_Base02 } from "./CrossMarginHandler_Base02.t.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

contract CrossMarginHandler_Initialization is CrossMarginHandler_Base02 {
  function setUp() public virtual override {
    super.setUp();
  }

  /**
   * TEST REVERT
   */

  function testRevert_setCrossMarginService() external {
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler02_InvalidAddress()"));
    crossMarginHandler.setCrossMarginService(address(0));
  }

  function testRevert_setPyth() external {
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginHandler02_InvalidAddress()"));
    crossMarginHandler.setPyth(address(0));
  }

  /**
   * TEST CORRECTNESS
   */

  function testCorrectness_crossMarginHandler_setCrossMarginService() external {
    ICrossMarginService newCrossMarginService = Deployer.deployCrossMarginService(
      address(proxyAdmin),
      address(configStorage),
      address(vaultStorage),
      address(perpStorage),
      address(calculator),
      address(convertedGlpStrategy)
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
