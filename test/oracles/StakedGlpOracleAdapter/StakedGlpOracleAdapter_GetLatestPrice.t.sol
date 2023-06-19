// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { StakedGlpOracleAdapter_BaseTest } from "./StakedGlpOracleAdapter_BaseTest.t.sol";

contract StakedGlpOracleAdapter_GetLatestPrice is StakedGlpOracleAdapter_BaseTest {
  function testRevert_WhenAssetNotStakedGlp() external {
    vm.expectRevert(abi.encodeWithSignature("StakedGlpOracleAdapter_BadAssetId()"));
    stakedGlpOracleAdapter.getLatestPrice("weth", true, 0);
  }

  function testCorrectness_WhenGetStakedGlpLatestMaxPrice() external {
    sglp.mint(address(this), 1 ether);
    mockGlpManager.setMaxAum(11e29);
    mockGlpManager.setMinAum(9e29);

    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sglpAssetId, true, 0);

    assertEq(price, 10e29);
    assertEq(timestamp, block.timestamp);
  }

  function testCorrectness_WhenGetGlpLatestMinPrice() external {
    sglp.mint(address(this), 1 ether);
    mockGlpManager.setMaxAum(11e29);
    mockGlpManager.setMinAum(9e29);

    (uint256 price, uint256 timestamp) = stakedGlpOracleAdapter.getLatestPrice(sglpAssetId, false, 0);

    assertEq(price, 10e29);
    assertEq(timestamp, block.timestamp);
  }
}
