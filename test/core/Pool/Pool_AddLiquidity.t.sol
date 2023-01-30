// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pool_BaseTest} from "./Pool_BaseTest.t.sol";

contract Pool_AddLiquidityTest is Pool_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  /// @notice Test revert when adding liquidity with unlisted token
  function testRevert_AddLiquidityWithUnlistedToken() external {
    int64[] memory priceData = new int64[](4);
    priceData[0] = 1_000;
    priceData[1] = 23_000;
    priceData[2] = 1;
    priceData[3] = 1;
    bytes[] memory pythUpdateData = buildPythUpdateData(priceData);

    vm.expectRevert(abi.encodeWithSignature("Pool_BadArgs()"));
    pool.addLiquidity(bad, 1 ether, 0, address(this), pythUpdateData);
  }

  /// @notice Test revert when adding liquidity with zero amount
  function testRevert_AddLiquidityWithZeroAmount() external {
    int64[] memory priceData = new int64[](4);
    priceData[0] = 1_000;
    priceData[1] = 23_000;
    priceData[2] = 1;
    priceData[3] = 1;
    bytes[] memory pythUpdateData = buildPythUpdateData(priceData);

    vm.expectRevert(abi.encodeWithSignature("Pool_InsufficientAmountIn()"));
    pool.addLiquidity{value: 4}(weth, 0, 0, address(this), pythUpdateData);
  }

  /// @notice Test correctness when msg.value > pythUpdateFee.
  /// It should refunds the correct amount.
  function testCorrectness_WhenMsgValueGreaterThanPythUpdateFee() external {
    int64[] memory priceData = new int64[](4);
    priceData[0] = 1_000;
    priceData[1] = 23_000;
    priceData[2] = 1;
    priceData[3] = 1;
    bytes[] memory pythUpdateData = buildPythUpdateData(priceData);

    uint256 amountIn = 1 ether;

    weth.mint(address(this), amountIn);
    weth.approve(address(pool), amountIn);

    uint256 balanceBefore = address(this).balance;
    pool.addLiquidity{value: 10}(
      weth, amountIn, 0, address(this), pythUpdateData
    );
    uint256 balanceAfter = address(this).balance;

    assertEq(weth.balanceOf(address(this)), 0);
    assertEq(weth.balanceOf(address(pool)), amountIn);
    assertEq(plpv2.balanceOf(address(this)), 1_000 * 1e18);
    assertEq(plpv2.totalSupply(), 1_000 * 1e18);
    assertEq(balanceAfter, balanceBefore - 4);
  }

  /// @notice Receive fallback to receive refunded ETH from the pool
  receive() external payable {}
}
