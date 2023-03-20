// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_BaseForkTest } from "./StakedGlpStrategy_Base.fork.sol";

contract StakedGlpStrategy_ExecuteForkTest is StakedGlpStrategy_BaseForkTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenTakeStakedGlpAsLiquidity() external {
    // Test states
    uint256 plpBalance = 0;
    uint256 fee = 0;

    // Provide 100 ETH liquidity on GMX
    vm.deal(address(this), 100 ether);
    gmxRewardRouterV2.mintAndStakeGlpETH{ value: 100 ether }(0, 0);
    assertEq(sGlp.balanceOf(address(this)), 170956355173943023662147);

    // Load min execution fee
    uint256 minExecutionFee = liquidityHandler.minExecutionFee();

    // Load how much 1 sGLP is worth in USD
    (uint256 sGlpMinPrice, ) = oracleMiddleware.getLatestPrice(sGlpAssetId, false);
    (uint256 sGlpMaxPrice, ) = oracleMiddleware.getLatestPrice(sGlpAssetId, true);

    // Provide 1,000 GLP liquidity on HMX
    sGlp.approve(address(liquidityHandler), 1_000 ether);
    liquidityHandler.createAddLiquidityOrder{ value: minExecutionFee }(
      address(sGlp),
      1_000 ether,
      0,
      minExecutionFee,
      false
    );

    // Calculate expected liquidity and fee
    (uint256 expectedLiquidity, uint256 expectedFee) = liquidityTester.expectLiquidityMint(sGlpAssetId, 1_000 ether);

    // Execute the add liquidity order
    vm.prank(keeper);
    liquidityHandler.executeOrder(address(this), 0, new bytes[](0));

    assertEq(plp.balanceOf(address(this)), plpBalance += expectedLiquidity);
    assertEq(vaultStorage.fees(sGlpAddress), fee += expectedFee);

    // Provide another 500 sGLP liquidity on HMX
    sGlp.approve(address(liquidityHandler), 500 ether);
    liquidityHandler.createAddLiquidityOrder{ value: minExecutionFee }(
      address(sGlp),
      500 ether,
      0,
      minExecutionFee,
      false
    );

    // Calculate expected liquidity and fee
    (expectedLiquidity, expectedFee) = liquidityTester.expectLiquidityMint(sGlpAssetId, 500 ether);

    // Execute the add liquidity order
    vm.prank(keeper);
    liquidityHandler.executeOrder(address(this), 1, new bytes[](0));

    assertEq(plp.balanceOf(address(this)), plpBalance += expectedLiquidity);
    assertEq(vaultStorage.fees(sGlpAddress), fee += expectedFee);
  }
}
