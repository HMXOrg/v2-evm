// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";
import { AddressUtils } from "@hmx/libraries/AddressUtils.sol";

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
  }

  // unsafe get latest price
  function testCorrectness_WhenUnsafeGetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint maxPrice, uint lastUpdate) = oracleMiddleware.unsafeGetLatestPrice(address(wbtc).toBytes32(), true, 1 ether);
    (uint minPrice, ) = oracleMiddleware.unsafeGetLatestPrice(address(wbtc).toBytes32(), false, 1 ether);
    assertEq(maxPrice, 20_500 * 1e30);
    assertEq(minPrice, 19_500 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.unsafeGetLatestPrice(address(168).toBytes32(), true, 1 ether);
  }

  // market status is undefined
  function testRevert_WhenUnsafeGetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(abi.encodeWithSignature("IOracleMiddleware_MarketStatusUndefined()"));
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(address(wbtc).toBytes32(), true, 1 ether);
  }

  // unsafe get latest price with market status
  function testCorrectness_WhenUnsafeGetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(
        address(wbtc).toBytes32(),
        true,
        1 ether
      );

      assertEq(marketStatus, 1);
    }

    // Change wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(2)); // active
    vm.stopPrank();
    {
      (, , uint8 marketStatus) = oracleMiddleware.unsafeGetLatestPriceWithMarketStatus(
        address(wbtc).toBytes32(),
        true,
        1 ether
      );
      assertEq(marketStatus, 2);
    }
  }
}
