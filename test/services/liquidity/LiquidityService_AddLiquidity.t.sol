// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";

import { LiquidityService } from "../../../src/services/LiquidityService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

// LiquidityService_AddLiquidity - unit test for add liquidity function
// What is this test DONE
// - correctness
//   - add liquidity with dynamic fee
//   - add liquidity without dynamic fee
// - revert
//   - add liquidity when circuit break
//   - add liquidity on unlisted token
//   - add liquidity on not accepted token
//   - add liquidity with zero amount
//   - slippage check fail
// What is this test not covered
//   - PLP transfer in cooldown period
//   - collect fee
contract LiquidityService_AddLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();

    // mint 100 WETH for ALICE
    weth.mint(address(this), 100 ether);
  }

  // add liquidity with dynamic fee
  function testCorrectness_WhenPLPAddLiquidity_WithDynamicFee() external {
    // approve 10 WETH for service
    weth.approve(address(liquidityService), 10 ether);
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity without dynamic fee
  function testCorrectness_WhenPLPAddLiquidity_WithoutDynamicFee() external {}

  // add liquidity when circuit break
  function testRevert_WhenCircuitBreak_PLPShouldNotAddLiquidity() external {
    // disable liquidity config
    IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage
      .getLiquidityConfig();
    _liquidityConfig.enabled = false;
    configStorage.setLiquidityConfig(_liquidityConfig);

    vm.expectRevert(
      abi.encodeWithSignature("LiquidityService_CircuitBreaker()")
    );
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity on unlisted token
  function testRevert_WhenPLPAddLiquidity_WithUnlistedToken() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_InvalidToken()"));
    // wbtc is not listed as plp token
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity on not accepted token
  function testRevert_WhenPLPAddLiquidity_WithNotAcceptedToken() external {
    // update weth to not accepted
    IConfigStorage.PLPTokenConfig memory _plpTokenConfig = configStorage
      .getPLPTokenConfig(address(weth));
    _plpTokenConfig.accepted = false;
    configStorage.setPlpTokenConfig(address(weth), _plpTokenConfig);

    vm.expectRevert(abi.encodeWithSignature("LiquidityService_InvalidToken()"));
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity with zero amount
  function testRevert_WhenPLPAddLiquidity_WithZeroAmount() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityService.addLiquidity(ALICE, address(weth), 0, 0);
  }

  // slippage check fail
  function testRevert_WhenPLPAddLiquidity_AndSlippageCheckFail() external {
    vm.expectRevert(
      abi.encodeWithSignature("LiquidityService_InsufficientLiquidityMint()")
    );
    liquidityService.addLiquidity(
      ALICE,
      address(weth),
      10 ether,
      type(uint256).max
    );
  }

  // function testRevert_WhenPLPTransferToken_AfterAddLiquidity_InCoolDownPeriod()
  //   external
  // {}
}
