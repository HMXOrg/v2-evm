// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pool_BaseTest} from "./Pool_BaseTest.t.sol";

contract Pool_AddLiquidityTest is Pool_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  /// @notice Test revert when adding liquidity with unlisted token
  function testRevert_AddLiquidityWithUnlistedToken() external {
    bytes[] memory pythUpdateData = new bytes[](4);
    pythUpdateData[0] = mockPyth.createPriceFeedUpdateData(
      wethPriceId,
      1_000 * 1e5,
      10 * 1e5,
      -5,
      1_000 * 1e5,
      10 * 1e15,
      uint64(block.timestamp)
    );
    pythUpdateData[1] = mockPyth.createPriceFeedUpdateData(
      wbtcPriceId,
      23_000 * 1e5,
      10 * 1e5,
      -5,
      23_000 * 1e5,
      10 * 1e15,
      uint64(block.timestamp)
    );
    pythUpdateData[2] = mockPyth.createPriceFeedUpdateData(
      usdcPriceId,
      1 * 1e5,
      1 * 1e2,
      -5,
      1 * 1e5,
      1 * 1e2,
      uint64(block.timestamp)
    );
    pythUpdateData[3] = mockPyth.createPriceFeedUpdateData(
      usdcPriceId,
      1 * 1e5,
      1 * 1e2,
      -5,
      1 * 1e5,
      1 * 1e2,
      uint64(block.timestamp)
    );

    vm.expectRevert(abi.encodeWithSignature("Pool_BadArgs()"));
    pool.addLiquidity(bad, 1 ether, 0, address(this), pythUpdateData);
  }
}
