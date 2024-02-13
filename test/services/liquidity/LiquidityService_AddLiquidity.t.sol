// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// LiquidityService_AddLiquidity - unit test for add liquidity function
// What is this test DONE
// - correctness
//   - add liquidity
// - revert
//   - add liquidity when circuit break
//   - remove liquidity when circuit break
//   - add liquidity on unlisted token
//   - add liquidity on not accepted token
//   - add liquidity with zero amount
//   - slippage check fail
// What is this test not covered
//   - HLP transfer in cooldown period
//   - collect fee
//   - add liquidity with dynamic fee (will be test in Calculator and integration test)
contract LiquidityService_AddLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();

    // mint 100 WETH for ALICE
    weth.mint(address(this), 100 ether);
  }

  // add liquidity
  function testCorrectness_WhenHLPAddLiquidity() external {
    ybusdb.approve(address(liquidityService), type(uint256).max);

    dealyb(payable(address(ybusdb)), address(vaultStorage), 100 ether);
    liquidityService.addLiquidity(ALICE, address(ybusdb), 100 ether, 0);

    assertEq(ybusdb.balanceOf(address(vaultStorage)), 100 ether, "VaultStorage should receive ybUSDB from Handler.");
    assertEq(hlp.totalSupply(), 99.7 ether, "HLP Total Supply");
  }

  function testRevert_WhenHLPAddLiquidity_WithInvalidHandler() external {
    vm.prank(BOB);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotWhiteListed()"));
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, type(uint256).max);
  }

  // add liquidity when circuit break
  function testRevert_WhenCircuitBreak_HLPShouldNotAddLiquidity() external {
    // disable liquidity config
    configStorage.setLiquidityEnabled(false);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityService.addLiquidity(ALICE, address(ybeth), 10 ether, 0);
  }

  // remove liquidity when circuit break
  function testRevert_WhenCircuitBreak_HLPShouldNotRemoveLiquidity() external {
    configStorage.setLiquidityEnabled(false);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityService.removeLiquidity(ALICE, address(ybeth), 10 ether, 0);
  }

  // add liquidity on unlisted token
  function testRevert_WhenHLPAddLiquidity_WithUnlistedToken() external {
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedLiquidity()"));
    // bad is not listed as hlp token
    liquidityService.addLiquidity(ALICE, address(bad), 10 ether, 0);
  }

  // add liquidity on not accepted token
  function testRevert_WhenHLPAddLiquidity_WithNotAcceptedToken() external {
    // update weth to not accepted
    IConfigStorage.HLPTokenConfig memory _hlpTokenConfig = configStorage.getAssetHlpTokenConfigByToken(address(weth));
    _hlpTokenConfig.accepted = false;
    configStorage.setHlpTokenConfig(address(weth), _hlpTokenConfig);

    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedLiquidity()"));
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity with zero amount
  function testRevert_WhenHLPAddLiquidity_WithZeroAmount() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityService.addLiquidity(ALICE, address(ybeth), 0, 0);
  }

  // slippage check fail
  function testRevert_WhenHLPAddLiquidity_AndSlippageCheckFail() external {
    dealyb(payable(address(ybeth)), address(vaultStorage), 10 ether);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_InsufficientLiquidityMint()"));
    liquidityService.addLiquidity(ALICE, address(ybeth), 10 ether, type(uint256).max);
  }

  // function testRevert_WhenHLPTransferToken_AfterAddLiquidity_InCoolDownPeriod()
  //   external
  // {}
}
