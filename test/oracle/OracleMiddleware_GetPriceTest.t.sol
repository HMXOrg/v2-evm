// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

// OracleMiddleware_GetPriceTest - test get price with validate price stale
// What is this test done
// - correctness
//   - get latest price with trust price
//   - get latest price with market status with trust price
// - revert
//   - get latest price but price is stale
//   - get latest price with market status market status is undefined
//   - get latest price with market status and price is stale
contract OracleMiddleware_GetPriceTest is OracleMiddleware_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);

    // set confident as 1e18 and trust price age 20 seconds
    OracleMiddleware(oracleMiddleware).setAssetPriceConfig(address(wbtc).toBytes32(), 1e18, 20);
  }

  // get latest price with trust price
  function testCorrectness_WhenGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint256 maxPrice, uint256 lastUpdate) = oracleMiddleware.getLatestPrice(address(wbtc).toBytes32(), true);
    (uint256 minPrice, ) = oracleMiddleware.getLatestPrice(address(wbtc).toBytes32(), false);

    assertEq(maxPrice, 20_500 * 1e30);
    assertEq(minPrice, 19_500 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.getLatestPrice(address(168).toBytes32(), true);
  }

  // get latest price with market status with trust price
  function testCorrectness_WhenGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);
      assertEq(marketStatus, 2);
    }
  }

  // get latest price but price is stale
  function testRevert_WhenGetLastestPriceButPriceIsStale() external {
    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    oracleMiddleware.getLatestPrice(address(wbtc).toBytes32(), true);
  }

  // get latest price with market status market status is undefined
  function testRevert_WhenGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.getLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);
  }

  // get latest price with market status and price is stale
  function testCorrectness_WhenGetWithMarketStatusButPriceIsStale() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    oracleMiddleware.getLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);
  }
}
