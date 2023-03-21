// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";

// OracleMiddleware_GetAdaptivePriceTest - test get price with validate price stale
// What is this test done
// - correctness
//   - get latest price with trust price
//   - get latest price with market status with trust price
// - revert
//   - get latest price but price is stale
//   - get latest price with market status market status is undefined
//   - get latest price with market status and price is stale
contract OracleMiddleware_GetAdaptivePriceTest is OracleMiddleware_BaseTest {
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
    (uint256 maxPrice, , uint256 lastUpdate) = oracleMiddleware.getLatestAdaptivePrice(wbtcAssetId, true, 0, 0, 0);
    (uint256 minPrice, , ) = oracleMiddleware.getLatestAdaptivePrice(wbtcAssetId, false, 0, 0, 0);

    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.getLatestAdaptivePrice("168", true, 0, 0, 0);
  }

  // get latest price with market status with trust price
  function testCorrectness_WhenGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(
        address(wbtc).toBytes32(),
        true,
        0,
        0,
        0
      );

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(
        address(wbtc).toBytes32(),
        true,
        0,
        0,
        0
      );
      assertEq(marketStatus, 2);
    }
  }

  // get latest price but price is stale
  function testRevert_WhenGetLastestPriceButPriceIsStale() external {
    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    oracleMiddleware.getLatestAdaptivePrice(address(wbtc).toBytes32(), true, 0, 0, 0);
  }

  // get latest price with market status market status is undefined
  function testRevert_WhenGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(wbtcAssetId, true, 0, 0, 0);
  }

  // get latest price with market status and price is stale
  function testCorrectness_WhenGetWithMarketStatusButPriceIsStale() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(1)); // inactive
    vm.stopPrank();

    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PriceStale()"));
    oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(address(wbtc).toBytes32(), true, 0, 0, 0);
  }

  function testCorrectness_getLatestPrice_premiumPrice() external {
    (uint256 maxPrice, , ) = oracleMiddleware.getLatestAdaptivePrice(
      wbtcAssetId,
      true,
      20_000 * 1e30, // 1 BTC Long skew
      500 * 1e30, // 500 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    (uint256 minPrice, , ) = oracleMiddleware.getLatestAdaptivePrice(
      wbtcAssetId,
      false,
      20_000 * 1e30, // 1 BTC Long skew
      500 * 1e30, // 500 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    // calculation
    // price          = 20000
    // market skew    = 20000
    // size delta     = 500
    // max scale skew = 1000000
    // premium (before) = 20000 / 1000000 = 0.02
    // premium (affter) = (20000 + 500) / 1000000 = 0.0205
    // medium = (0.02 + 0.0205) / 2 = 0.02025
    // adaptive price = 20000 * (1 + 0.02025) = 20405

    assertEq(maxPrice, 20405 * 1e30);
    // note: unsupport min, max price logic then min & max price should be same
    assertEq(minPrice, maxPrice);
  }

  function testCorrectness_getLatestPrice_discountPrice() external {
    (uint256 maxPrice, , ) = oracleMiddleware.getLatestAdaptivePrice(
      wbtcAssetId,
      true,
      -5 * 1e18, // 5 BTC Short skew
      7200 * 1e30, // 7200 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    (uint256 minPrice, , ) = oracleMiddleware.getLatestAdaptivePrice(
      wbtcAssetId,
      false,
      -5 * 1e18, // 5 BTC Short skew
      7200 * 1e30, // 7200 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    // calculation
    // price          = 20000
    // market skew    = -100000
    // size delta     = 7200
    // max scale skew = 1000000
    // premium (before) = -100000 / 1000000 = -0.1
    // premium (affter) = (-100000 + -(7200)) / 1000000 = -0.1072
    // medium = (-0.1 - 0.1072) / 2 = -0.1036
    // adaptive price = 20000 * (1 + -0.1036) = 17928

    assertEq(maxPrice, 17928 * 1e30);
    // note: unsupport min, max price logic then min & max price should be same
    assertEq(minPrice, maxPrice);
  }
}
