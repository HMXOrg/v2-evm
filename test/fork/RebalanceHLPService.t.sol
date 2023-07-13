// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract RebalanceHLPSerivce is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();

    deal(wethAddress, address(vaultStorage), 1_000 ether);
    vaultStorage.pullToken(wethAddress);
    vaultStorage.addHLPLiquidity(wethAddress, 1_000 ether);
    deal(usdcAddress, address(vaultStorage), 10000 * 1e6);
    vaultStorage.pullToken(usdcAddress);
    vaultStorage.addHLPLiquidity(usdcAddress, 10000 * 1e6);
  }

  function testCorrectness_RebalanceSuccess() external {
    IRebalanceHLPService.ExecuteParams[] memory params = new IRebalanceHLPService.ExecuteParams[](2);
    uint256 usdcAmount = 1000 * 1e6;
    uint256 wethAmount = 1 * 1e18;

    params[0] = IRebalanceHLPService.ExecuteParams(usdcAddress, usdcAmount, 990 * 1e6, 100);
    params[1] = IRebalanceHLPService.ExecuteParams(wethAddress, wethAmount, 95 * 1e16, 100);

    uint256 usdcBefore = vaultStorage.hlpLiquidity(usdcAddress);
    uint256 wethBefore = vaultStorage.hlpLiquidity(wethAddress);
    uint256 sGlpBefore = vaultStorage.hlpLiquidity(address(sglp));

    uint256 receivedGlp = rebalanceHLPSerivce.execute(params);

    // USDC
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), usdcBefore - usdcAmount);
    assertEq(vaultStorage.hlpLiquidity(usdcAddress), vaultStorage.totalAmount(usdcAddress));
    // WETH
    assertEq(vaultStorage.hlpLiquidity(wethAddress), wethBefore - wethAmount);
    assertEq(vaultStorage.hlpLiquidity(wethAddress), vaultStorage.totalAmount(wethAddress));
    // sGLP
    assertEq(receivedGlp, vaultStorage.hlpLiquidity(address(sglp)) - sGlpBefore);

    // make sure that the allowance is zero
    assertEq(IERC20Upgradeable(usdcAddress).allowance(address(rebalanceHLPSerivce), address(glpManager)), 0);
    assertEq(IERC20Upgradeable(wethAddress).allowance(address(rebalanceHLPSerivce), address(glpManager)), 0);
  }

  function testRevert_ReinvestEmptyParams() external {
    IRebalanceHLPService.ExecuteParams[] memory params;
    vm.expectRevert(IRebalanceHLPService.RebalanceHLPService_ParamsIsEmpty.selector);
    rebalanceHLPSerivce.execute(params);
  }
}