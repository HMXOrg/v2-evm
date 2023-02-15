// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

contract OracleMiddleware_SetterTest is OracleMiddleware_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_AccessControlWhenSetUpdater() external {
    assertFalse(oracleMiddleware.isUpdater(ALICE));

    // Only owner could setUpdater()
    vm.expectRevert(abi.encodeWithSignature("Owned_NotOwner()"));
    vm.startPrank(ALICE);
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    assertTrue(oracleMiddleware.isUpdater(ALICE));
  }

  function testCorrectness_AccessControlWhenSetMarketStatus() external {
    assertEq(oracleMiddleware.marketStatus(address(wbtc).toBytes32()), 0);
    // Only updater could setMarketStatus()
    vm.expectRevert(abi.encodeWithSignature("OracleMiddleware_OnlyUpdater()"));
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), 2);
    vm.stopPrank();

    // Try set ALICE as updater
    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), 2);
    vm.stopPrank();

    assertEq(oracleMiddleware.marketStatus(address(wbtc).toBytes32()), 2);
  }

  function testRevert_WhenSetMarketStatusInvalidValue() external {
    // Try Set ALICE as updater
    vm.startPrank(address(this));
    oracleMiddleware.setUpdater(ALICE, true);
    vm.stopPrank();

    vm.startPrank(ALICE);

    // Revert if status > 2
    vm.expectRevert(
      abi.encodeWithSignature("OracleMiddleware_InvalidMarketStatus()")
    );
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), 3);

    // Revert if status > 2
    vm.expectRevert(
      abi.encodeWithSignature("OracleMiddleware_InvalidMarketStatus()")
    );
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), 4);

    // This one should be ok
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), 1);
    vm.stopPrank();

    assertEq(oracleMiddleware.marketStatus(address(wbtc).toBytes32()), 1);
  }
}
