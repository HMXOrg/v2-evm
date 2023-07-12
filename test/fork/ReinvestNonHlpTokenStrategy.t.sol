// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { IReinvestNonHlpTokenStrategy } from "@hmx/strategies/interfaces/IReinvestNonHlpTokenStrategy.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract ReinvestNonHlpTokenStrategy is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();

    deal(wethAddress, address(vaultStorage), 1_000 ether);
    vaultStorage.pullToken(wethAddress);
    vaultStorage.addHLPLiquidity(wethAddress, 1_000 ether);
    deal(usdcAddress, address(vaultStorage), 10000 * 1e6);
    vaultStorage.pullToken(usdcAddress);
    vaultStorage.addHLPLiquidity(usdcAddress, 10000 * 1e6);
    IERC20Upgradeable(usdcAddress).approve(address(reinvestStrategy), type(uint256).max);
    IERC20Upgradeable(wethAddress).approve(address(reinvestStrategy), type(uint256).max);
  }

  function testCorrectness_ReinvestSuccess() external {
    IReinvestNonHlpTokenStrategy.ExecuteParams[] memory params = new IReinvestNonHlpTokenStrategy.ExecuteParams[](2);
    uint256 usdcAmount = 1000 * 1e6;
    uint256 wethAmount = 1 * 1e18;
    params[0] = IReinvestNonHlpTokenStrategy.ExecuteParams(usdcAddress, usdcAmount, 990 * 1e6, 100);
    params[1] = IReinvestNonHlpTokenStrategy.ExecuteParams(wethAddress, wethAmount, 95 * 1e16, 100);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethBefore = vaultStorage.hlpLiquidity(wethAddress);

    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));
    uint256 receivedGlp = reinvestStrategy.execute(params);
    uint256 sGlpAfter = vaultStorage.hlpLiquidity(address(sglp));

    // USDC
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), usdcBefore - usdcAmount);
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), vaultStorage.totalAmount(usdcAddress));
    // WETH
    assertEq(vaultStorage.hlpLiquidity(wethAddress), wethBefore - wethAmount);
    assertEq(vaultStorage.hlpLiquidity(wethAddress), vaultStorage.totalAmount(wethAddress));
    // sGLP
    assertEq(receivedGlp, sGlpAfter - sGlpBefore);
  }

  function testRevert_ReinvestEmptyParams() external {
    IReinvestNonHlpTokenStrategy.ExecuteParams[] memory params;
    vm.expectRevert(IReinvestNonHlpTokenStrategy.ReinvestNonHlpTokenStrategy_ParamsIsEmpty.selector);
    reinvestStrategy.execute(params);
  }
}
