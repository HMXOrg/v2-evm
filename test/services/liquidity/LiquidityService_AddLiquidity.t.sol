// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

// LiquidityService_AddLiquidity - unit test for add liquidity function
// What is this test DONE
// - correctness
//   - add liquidity
// - revert
//   - add liquidity when circuit break
//   - add liquidity on unlisted token
//   - add liquidity on not accepted token
//   - add liquidity with zero amount
//   - slippage check fail
// What is this test not covered
//   - PLP transfer in cooldown period
//   - collect fee
//   - add liquidity with dynamic fee (will be test in Calculator and integration test)
contract LiquidityService_AddLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();

    // mint 100 WETH for ALICE
    weth.mint(address(this), 100 ether);
  }

  // add liquidity
  function testCorrectness_WhenPLPAddLiquidity() external {
    dai.mint(address(this), 100 ether);
    dai.approve(address(liquidityService), type(uint256).max);
    liquidityService.addLiquidity(ALICE, address(dai), 100 ether, 0);

    assertEq(dai.balanceOf(address(this)), 0, "DAI should be transferred from Handler.");
    assertEq(dai.balanceOf(address(vaultStorage)), 100 ether, "VaultStorage should receive DAI from Handler.");
    assertEq(plp.totalSupply(), 99.7 ether, "PLP Total Supply");
    assertEq(vaultStorage.plpTotalLiquidityUSDE30(), 99.7 * 10 ** 30);
  }

  // add liquidity when circuit break
  function testRevert_WhenCircuitBreak_PLPShouldNotAddLiquidity() external {
    // disable liquidity config
    IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
    _liquidityConfig.enabled = false;
    configStorage.setLiquidityConfig(_liquidityConfig);

    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, 0);
  }

  // add liquidity on unlisted token
  function testRevert_WhenPLPAddLiquidity_WithUnlistedToken() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_InvalidToken()"));
    // bad is not listed as plp token
    liquidityService.addLiquidity(ALICE, address(bad), 10 ether, 0);
  }

  // add liquidity on not accepted token
  function testRevert_WhenPLPAddLiquidity_WithNotAcceptedToken() external {
    // update weth to not accepted
    IConfigStorage.PLPTokenConfig memory _plpTokenConfig = configStorage.getPLPTokenConfig(address(weth));
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
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_InsufficientLiquidityMint()"));
    liquidityService.addLiquidity(ALICE, address(weth), 10 ether, type(uint256).max);
  }

  // function testRevert_WhenPLPTransferToken_AfterAddLiquidity_InCoolDownPeriod()
  //   external
  // {}
}
