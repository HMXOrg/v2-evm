// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";

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
  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);

    // set confident as 1e18 and trust price age 20 seconds
    oracleMiddleware.setAssetPriceConfig(wbtcAssetId, 1e6, 20);
  }

  // get latest price with trust price
  function testCorrectness_WhenGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint256 maxPrice, uint256 lastUpdate) = oracleMiddleware.getLatestPrice(wbtcAssetId, true);
    (uint256 minPrice, ) = oracleMiddleware.getLatestPrice(wbtcAssetId, false);

    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.getLatestPrice("168", true);
  }

  // get latest price with market status with trust price
  function testCorrectness_WhenGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestPriceWithMarketStatus(wbtcAssetId, true);
      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestPriceWithMarketStatus(wbtcAssetId, true);
      assertEq(marketStatus, 2);
    }
  }

  // get latest price but price is stale
  function testRevert_WhenGetLastestPriceButPriceIsStale() external {
    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    oracleMiddleware.getLatestPrice(wbtcAssetId, true);
  }

  // get latest price with market status market status is undefined
  function testRevert_WhenGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.getLatestPriceWithMarketStatus(wbtcAssetId, true);
  }

  // get latest price with market status and price is stale
  function testCorrectness_WhenGetWithMarketStatusButPriceIsStale() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(1)); // inactive
    vm.stopPrank();

    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    oracleMiddleware.getLatestPriceWithMarketStatus(wbtcAssetId, true);
  }
}
