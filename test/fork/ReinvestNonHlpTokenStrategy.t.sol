// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import "forge-std/console.sol";
import { GlpStrategy_Base } from "./GlpStrategy_Base.t.fork.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ReinvestNonHlpTokenStrategy is GlpStrategy_Base {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  struct ExecuteParams {
    address token;
    uint256 amount;
    uint256 minAmountOutUSD;
    uint256 minAmountOutGlp;
  }

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ReinvestSuccess() external {
    ExecuteParams[] memory params = new ExecuteParams[](3);
    console.log("usdc in vault:", vaultStorage.hlpLiquidity(usdcAddress));
    console.log("weth in vault:", vaultStorage.hlpLiquidity(wethAddress));
  }
}
