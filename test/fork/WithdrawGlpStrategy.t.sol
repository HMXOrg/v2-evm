// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { IWithdrawGlpStrategy } from "@hmx/strategies/interfaces/IWithdrawGlpStrategy.sol";
import { IReinvestNonHlpTokenStrategy } from "@hmx/strategies/interfaces/IReinvestNonHlpTokenStrategy.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract WithdrawGlpStrategy is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();

    deal(wethAddress, address(vaultStorage), 10 ether);
    vaultStorage.pullToken(wethAddress);
    vaultStorage.addHLPLiquidity(wethAddress, 10 ether);
    deal(usdcAddress, address(vaultStorage), 10000 * 1e6);
    vaultStorage.pullToken(usdcAddress);
    vaultStorage.addHLPLiquidity(usdcAddress, 10000 * 1e6);

    // mint Glp into vault
    IReinvestNonHlpTokenStrategy.ExecuteParams[] memory params = new IReinvestNonHlpTokenStrategy.ExecuteParams[](2);
    uint256 usdcAmount = 1000 * 1e6;
    uint256 wethAmount = 10 * 1e18;
    params[0] = IReinvestNonHlpTokenStrategy.ExecuteParams(usdcAddress, usdcAmount, 990 * 1e6, 100);
    params[1] = IReinvestNonHlpTokenStrategy.ExecuteParams(wethAddress, wethAmount, 95 * 1e16, 100);
    reinvestStrategy.execute(params);

    console.log("Vault owns sGLP:", vaultStorage.hlpLiquidity(address(sglp)));
    console.log("sGLP Balance:", sglp.balanceOf(address(vaultStorage)));
  }

  function testCorrectness_WithdrawGlpSuccess() external {
    IWithdrawGlpStrategy.ExecuteParams[] memory params = new IWithdrawGlpStrategy.ExecuteParams[](1);
    params[0] = IWithdrawGlpStrategy.ExecuteParams(usdcAddress, 100 * 1e18, 0);
    // params[1] = IWithdrawGlpStrategy.ExecuteParams(wethAddress, 0, 0);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethBefore = vaultStorage.hlpLiquidity(wethAddress);
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    withdrawStrategy.execute(params);

    uint256 sGlpAfter = vaultStorage.hlpLiquidity(address(sglp));

    // USDC
    assertFalse(vaultStorage.hlpLiquidity(usdcAddress) > usdcBefore);
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), vaultStorage.totalAmount(usdcAddress));
    // WETH
    // assertFalse(vaultStorage.hlpLiquidity(wethAddress) > wethBefore);
    assertEq(vaultStorage.hlpLiquidity(wethAddress), vaultStorage.totalAmount(wethAddress));
    // sGLP
    assertEq(100 * 1e18, sGlpBefore - sGlpAfter);
  }

  function testRevert_WithdrawGlpEmptyParams() external {
    IWithdrawGlpStrategy.ExecuteParams[] memory params;
    vm.expectRevert(IWithdrawGlpStrategy.WithdrawGlpStrategy_ParamsIsEmpty.selector);
    withdrawStrategy.execute(params);
  }
}
