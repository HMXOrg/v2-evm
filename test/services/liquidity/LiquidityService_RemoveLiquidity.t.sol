// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";

import { LiquidityService } from "../../../src/services/LiquidityService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

// LiquidityService_RemoveLiquidity - unit test for remove liquidity function
// What is this test DONE
// - correctness
//   - remove liquidity with dynamic fee
//   - remove liquidity without dynamic fee
// - revert
//   - remove liquidity of another PLP
//   - remove with zero amount
//   - remove liquidity in cooldown period
//   - fail on slippage

contract LiquidityService_RemoveLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  function testCorrectness_WhenPLPRemoveLiquidity_WithDynamicFee() external {}

  function testCorrectness_WhenPLPRemoveLiquidity_WithoutDynamicFee()
    external
  {}

  function testRevert_WhenPLPRemoveLiquidityOfAnotherPLP() external {}

  function testRevert_WhenPLPRemoveLiquidity_WithZeroAmount() external {}

  function testRevert_WhenPLPRemoveLiquidity_AfterAddLiquidity_InCoolDownPeriod()
    external
  {}

  function testRevert_WhenPLPRemoveLiquidity_AndSlippageCheckFail() external {}
}
