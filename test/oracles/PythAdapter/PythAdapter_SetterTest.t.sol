// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PythAdapter_BaseTest } from "./PythAdapter_BaseTest.t.sol";
import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";

contract PythAdapter_SetterTest is PythAdapter_BaseTest {
  function setUp() public override {
    super.setUp();

    vm.deal(ALICE, 1 ether);
    vm.deal(BOB, 1 ether);
  }

  function testCorrectness_AccessControlWhenSetConfig() external {
    // Revert if not owner
    vm.expectRevert(abi.encodeWithSignature("Owned_NotOwner()"));
    vm.startPrank(address(ALICE));
    pythAdapter.setConfig(wethAssetId, wethPriceId, false);
    vm.stopPrank();

    // Should be fine when executed by owner
    vm.startPrank(address(this));
    pythAdapter.setConfig(wethAssetId, wethPriceId, false);
    vm.stopPrank();
  }
}
