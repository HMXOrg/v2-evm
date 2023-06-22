// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";

contract OracleMiddleware_SetterTest is OracleMiddleware_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_AccessControlWhenSetUpdater() external {
    assertFalse(oracleMiddleware.isUpdater(ALICE));

    // Only owner could setUpdater()
    vm.expectRevert("Ownable: caller is not the owner");
    vm.startPrank(ALICE);
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    assertTrue(oracleMiddleware.isUpdater(ALICE));
  }

  function testCorrectness_AccessControlWhenSetMarketStatus() external {
    assertEq(oracleMiddleware.marketStatus(wbtcAssetId), 0);
    // Only updater could setMarketStatus()
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_OnlyUpdater()"));
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, 2);
    vm.stopPrank();

    // Try set ALICE as updater
    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, 2);
    vm.stopPrank();

    assertEq(oracleMiddleware.marketStatus(wbtcAssetId), 2);
  }

  function testRevert_WhenSetMarketStatusInvalidValue() external {
    // Try Set ALICE as updater
    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(ALICE);

    // Revert if status > 2
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_InvalidMarketStatus()"));
    oracleMiddleware.setMarketStatus(wbtcAssetId, 3);

    // Revert if status > 2
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_InvalidMarketStatus()"));
    oracleMiddleware.setMarketStatus(wbtcAssetId, 4);

    // This one should be ok
    oracleMiddleware.setMarketStatus(wbtcAssetId, 1);
    vm.stopPrank();

    assertEq(oracleMiddleware.marketStatus(wbtcAssetId), 1);
  }
}
