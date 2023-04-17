// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { StakedGlpStrategy_BaseForkTest } from "./StakedGlpStrategy_Base.t.fork.sol";

contract StakedGlpStrategy_ForkTest is StakedGlpStrategy_BaseForkTest {
  uint256 arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"));

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_ClaimSuccess_ReinvestSuccess() external {
    //gmxManager.addLiquidity for getting GLP
    // vm.prank(keeper);
    // stakedGlpStrategy.execute();
    // vm.stopPrank();
  }
}
