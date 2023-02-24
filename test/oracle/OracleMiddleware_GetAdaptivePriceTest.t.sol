// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

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
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);
  }

  // get latest price with trust price
  function testCorrectness_WhenGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint256 maxPrice, uint256 lastUpdate) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      true,
      1 ether,
      60, // trust price age 60 seconds
      0,
      0,
      0
    );
    (uint256 minPrice, ) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      false,
      1 ether,
      60, // trust price age 60 seconds
      0,
      0,
      0
    );

    assertEq(maxPrice, 20_500 * 1e30);
    assertEq(minPrice, 19_500 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.getLatestAdaptivePrice(address(168).toBytes32(), 8, true, 1 ether, 60, 0, 0, 0);
  }

  // get latest price with market status with trust price
  function testCorrectness_WhenGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(
        address(wbtc).toBytes32(),
        8,
        true,
        1 ether,
        60,
        0,
        0,
        0
      );

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(
        address(wbtc).toBytes32(),
        8,
        true,
        1 ether,
        60,
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
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    oracleMiddleware.getLatestAdaptivePrice(address(wbtc).toBytes32(), 8, true, 1 ether, 0, 0, 0, 0);
  }

  // get latest price with market status market status is undefined
  function testRevert_WhenGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(address(wbtc).toBytes32(), 8, true, 1 ether, 60, 0, 0, 0);
  }

  // get latest price with market status and price is stale
  function testCorrectness_WhenGetWithMarketStatusButPriceIsStale() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    vm.warp(block.timestamp + 30);
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_PythPriceStale()"));
    oracleMiddleware.getLatestAdaptivePriceWithMarketStatus(address(wbtc).toBytes32(), 8, true, 1 ether, 0, 0, 0, 0);
  }

  function testCorrectness_getLatestPrice_premiumPrice() external {
    // maxPrice is 20_500
    (uint256 maxPrice, ) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      true,
      1 ether,
      60, // trust price age 60 seconds
      1 * 1e8, // 1 BTC Long skew
      500 * 1e30, // 500 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    assertEq(maxPrice, 20925.375 * 1e30);

    // minPrice is 19_500
    (uint256 minPrice, ) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      false,
      1 ether,
      60, // trust price age 60 seconds
      1 * 1e8, // 1 BTC Long skew
      500 * 1e30, // 500 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    assertEq(minPrice, 19885.125 * 1e30);
  }

  function testCorrectness_getLatestPrice_discountPrice() external {
    // maxPrice is 20_500
    (uint256 maxPrice, ) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      true,
      1 ether,
      60, // trust price age 60 seconds
      -5 * 1e8, // 5 BTC Short skew
      7200 * 1e30, // 7200 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    assertEq(maxPrice, 18472.55 * 1e30);

    // minPrice is 19_500
    (uint256 minPrice, ) = oracleMiddleware.getLatestAdaptivePrice(
      address(wbtc).toBytes32(),
      8,
      false,
      1 ether,
      60, // trust price age 60 seconds
      -5 * 1e8, // 5 BTC Short skew
      7200 * 1e30, // 7200 USD sizeDelta
      1_000_000 * 1e30 // 1M Skew Scale
    );

    assertEq(minPrice, 17668.95 * 1e30);
  }
}
