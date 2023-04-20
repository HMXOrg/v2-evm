// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpOracleAdapter_BaseTest } from "./StakedGlpOracleAdapter_BaseTest.t.sol";

contract StakedGlpOracleAdapter_GetLatestPrice is StakedGlpOracleAdapter_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenAssetNotStakedGlp() external {
    vm.expectRevert(abi.encodeWithSignature("StakedGlpOracleAdapter_BadAssetId()"));
    stakedGlpOracleAdapter.getLatestPrice("weth", true, 0);
  }

  function testCorrectness_WhenGetStakedGlpLatestMaxPrice() external {
    // Assuming GLP's max price is 1.1 USD
    sGlp.mint(address(this), 1 ether);
    mockGlpManager.setMaxAum(11e29);

    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sGlpAssetId, true, 0);

    assertEq(price, 11e29);
    assertEq(timestamp, block.timestamp);
  }

  function testCorrectness_WhenGetGlpLatestMinPrice() external {
    // Assuming GLP's min price is 0.9 USD
    sGlp.mint(address(this), 1 ether);
    mockGlpManager.setMinAum(9e29);

    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sGlpAssetId, false, 0);

    assertEq(price, 9e29);
    assertEq(timestamp, block.timestamp);
  }
}
