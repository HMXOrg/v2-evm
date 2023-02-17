// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "../../base/BaseTest.sol";

import { LiquidityService } from "../../../src/services/LiquidityService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

// LiquidityService_AddLiquidity - unit test for add liquidity function
// What is this test DONE
// - correctness
//   - add liquidity with dynamic fee
//   - add liquidity without dynamic fee
// - revert
//   - add liquidity on unlisted token
//   - add liquidity on not accepted token
//   - add liquidity with zero amount
//   - slippage check fail
//   - PLP transfer in cooldown period
abstract contract LiquidityService_AddLiquidity is BaseTest {
  LiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = new LiquidityService(
      address(configStorage),
      address(vaultStorage)
    );
  }

  function testCorrectness_WhenPLPAddLiquidity_WithDynamicFee() external {}

  function testCorrectness_WhenPLPAddLiquidity_WithoutDynamicFee() external {}

  function testRevert_WhenPLPAddLiquidity_WithUnlistedToken() external {}

  function testRevert_WhenPLPAddLiquidity_WithNotAcceptedToken() external {}

  function testRevert_WhenPLPAddLiquidity_WithZeroAmount() external {}

  function testRevert_WhenPLPAddLiquidity_AndSlippageCheckFail() external {}

  function testRevert_WhenPLPTransferToken_AfterAddLiquidity_InCoolDownPeriod()
    external
  {}
}
