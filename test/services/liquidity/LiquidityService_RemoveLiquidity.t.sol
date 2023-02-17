// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";

import { LiquidityService } from "../../../src/services/LiquidityService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

// LiquidityService_RemoveLiquidity - unit test for remove liquidity function
// What is this test DONE
//   - remove liquidity with dynamic fee
//   - remove liquidity without dynamic fee
// - revert
//   - remove liquidity when circuit break
//   - remove with zero amount
//   - fail on slippage
// What is this test not covered
// - correctness
//   - remove liquidity of another PLP
// - revert
//   - PLP transfer in cooldown period
contract LiquidityService_RemoveLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_WhenPLPRemoveLiquidity_WithDynamicFee() external {}

  function testCorrectness_WhenPLPRemoveLiquidity_WithoutDynamicFee()
    external
  {}

  // add liquidity when circuit break
  function testRevert_WhenCircuitBreak_PLPShouldNotRemoveLiquidity() external {
    // disable liquidity config
    IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage
      .getLiquidityConfig();
    _liquidityConfig.enabled = false;
    configStorage.setLiquidityConfig(_liquidityConfig);

    vm.expectRevert(
      abi.encodeWithSignature("LiquidityService_CircuitBreaker()")
    );
    liquidityService.removeLiquidity(ALICE, address(wbtc), 10 ether, 0);
  }

  function testRevert_WhenPLPRemoveLiquidity_WithZeroAmount() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityService.removeLiquidity(ALICE, address(weth), 0, 0);
  }

  function testRevert_WhenPLPRemoveLiquidity_AndSlippageCheckFail() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_Slippage()"));
    liquidityService.removeLiquidity(
      ALICE,
      address(weth),
      10 ether,
      type(uint256).max
    );
  }

  // function testRevert_WhenPLPRemoveLiquidity_AfterAddLiquidity_InCoolDownPeriod()
  //   external
  // {}
}
