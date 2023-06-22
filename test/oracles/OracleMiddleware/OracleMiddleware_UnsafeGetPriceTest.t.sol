// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";

// OracleMiddleware_UnsafeGetPriceTest - test get price without validate price stale
// What is this test done
// - correctness
//   - unsafe get latest price
//   - unsafe get latest price with market status
// revert
//   - market status is undefined
//

contract OracleMiddleware_UnsafeGetPriceTest is OracleMiddleware_BaseTest {
  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);

    // set confident as 1e18 and trust price age 20 seconds
    oracleMiddleware.setAssetPriceConfig(wbtcAssetId, 1e6, 20, address(pythAdapter));
  }

  // unsafe get latest price
  function testCorrectness_WhenUnsafeGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint maxPrice, uint lastUpdate) = oracleMiddleware.unsafeGetLatestPrice(wbtcAssetId, true);
    (uint minPrice, ) = oracleMiddleware.unsafeGetLatestPrice(wbtcAssetId, false);
    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.unsafeGetLatestPrice("168", true);
  }

  // market status is undefined
  function testRevert_WhenUnsafeGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(wbtcAssetId, true);
  }

  // unsafe get latest price with market status
  function testCorrectness_WhenUnsafeGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(wbtcAssetId, true);

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(wbtcAssetId, uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(wbtcAssetId, true);
      assertEq(marketStatus, 2);
    }
  }
}
