// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { GlpStrategy_BaseForkTest } from "./GlpStrategy_Base.fork.sol";

contract GlpStrategy_ExecuteForkTest is GlpStrategy_BaseForkTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenTakeStkGlpAsLiquidity() external {
    // Provide 100 ETH liquidity on GMX
    vm.deal(address(this), 100 ether);
    gmxRewardRouterV2.mintAndStakeGlpETH{ value: 100 ether }(0, 0);
    assertEq(stkGlp.balanceOf(address(this)), 170956355173943023662147);

    // Load min execution fee
    uint256 minExecutionFee = liquidityHandler.minExecutionFee();

    // Provide 1,000 GLP liquidity on HMX
    stkGlp.approve(address(liquidityHandler), 1_000 ether);
    liquidityHandler.createAddLiquidityOrder{ value: minExecutionFee }(
      address(stkGlp),
      1_000 ether,
      0,
      minExecutionFee,
      false
    );

    // Execute the add liquidity order
    vm.prank(keeper);
    liquidityHandler.executeOrder(address(this), 0, new bytes[](0));
  }
}
