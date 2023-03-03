// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

// OracleMiddleware_UnsafeGetPriceTest - test get price without validate price stale
// What is this test done
// - correctness
//   - unsafe get latest price
//   - unsafe get latest price with market status
// revert
//   - market status is undefined
//

contract OracleMiddleware_UnsafeGetPriceTest is OracleMiddleware_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);

    // set confident as 1e18 and trust price age 20 seconds
    OracleMiddleware(oracleMiddleware).setAssetPriceConfig(address(wbtc).toBytes32(), 1e6, 20);
  }

  // unsafe get latest price
  function testCorrectness_WhenUnsafeGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint maxPrice, , uint lastUpdate) = oracleMiddleware.unsafeGetLatestPrice(address(wbtc).toBytes32(), true);
    (uint minPrice, , ) = oracleMiddleware.unsafeGetLatestPrice(address(wbtc).toBytes32(), false);
    assertEq(maxPrice, 20_500 * 1e30);
    assertEq(minPrice, 19_500 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.unsafeGetLatestPrice(address(168).toBytes32(), true);
  }

  // market status is undefined
  function testRevert_WhenUnsafeGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);
  }

  // unsafe get latest price with market status
  function testCorrectness_WhenUnsafeGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true);
      assertEq(marketStatus, 2);
    }
  }
}
