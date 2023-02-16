// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

contract OracleMiddleware_GetPriceTest is OracleMiddleware_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
    oracleMiddleware.setUpdater(ALICE, true);
  }

  function testCorrectness_GetLatestPrice() external {
    // Should get price via PythAdapter successfully.
    // For more edge cases see PythAdapter_GetPriceTest.t.sol
    (uint256 maxPrice, uint256 lastUpdate) = oracleMiddleware.getLatestPrice(
      address(wbtc).toBytes32(),
      true,
      1 ether
    );
    (uint256 minPrice, ) = oracleMiddleware.getLatestPrice(
      address(wbtc).toBytes32(),
      false,
      1 ether
    );
    assertEq(maxPrice, 20_500 * 1e30);
    assertEq(minPrice, 19_500 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));

    // Revert on unknown asset id
    vm.expectRevert();
    oracleMiddleware.getLatestPrice(address(168).toBytes32(), true, 1 ether);
  }

  function testRevert_GetWithMarketStatusWhenMarketStatusUndefined() external {
    vm.expectRevert(
      abi.encodeWithSignature("OracleMiddleware_MarketStatusUndefined()")
    );
    // Try get wbtc price which we never set its status before.
    oracleMiddleware.getLatestPriceWithMarketStatus(
      address(wbtc).toBytes32(),
      true,
      1 ether
    );
  }

  function testCorrectness_GetWithMarketStatus() external {
    // Set wbtc market status
    vm.startPrank(ALICE);
    oracleMiddleware.setMarketStatus(address(wbtc).toBytes32(), uint8(1)); // inactive
    vm.stopPrank();

    {
      (, , uint8 marketStatus) = oracleMiddleware
        .getLatestPriceWithMarketStatus(
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
      (, , uint8 marketStatus) = oracleMiddleware
        .getLatestPriceWithMarketStatus(
          address(wbtc).toBytes32(),
          true,
          1 ether
        );
      assertEq(marketStatus, 2);
    }
  }
}
