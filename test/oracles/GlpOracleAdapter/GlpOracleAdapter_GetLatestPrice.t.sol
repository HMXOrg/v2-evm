// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { GlpOracleAdapter_BaseTest } from "./GlpOracleAdapter_BaseTest.t.sol";
import { AddressUtils } from "../../../src/libraries/AddressUtils.sol";

contract GlpOracleAdapter_GetLatestPriceTest is GlpOracleAdapter_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenAssetNotGlp() external {
    vm.expectRevert(abi.encodeWithSignature("GlpOracleAdapter_BadAssetId()"));
    glpOracleAdapter.getLatestPrice(address(weth).toBytes32(), true, 0);
  }

  function testCorrectness_WhenGetGlpLatestMaxPrice() external {
    // Assuming GLP's max price is 1.1 USD
    stkGlp.mint(address(this), 1 ether);
    mockGlpManager.setMaxAum(11e29);

    (uint256 price, uint256 timestamp) = glpOracleAdapter.getLatestPrice(address(stkGlp).toBytes32(), true, 0);

    assertEq(price, 11e29);
    assertEq(timestamp, block.timestamp);
  }

  function testCorrectness_WhenGetGlpLatestMinPrice() external {
    // Assuming GLP's min price is 0.9 USD
    stkGlp.mint(address(this), 1 ether);
    mockGlpManager.setMinAum(9e29);

    (uint256 price, uint256 timestamp) = glpOracleAdapter.getLatestPrice(address(stkGlp).toBytes32(), false, 0);

    assertEq(price, 9e29);
    assertEq(timestamp, block.timestamp);
  }
}
