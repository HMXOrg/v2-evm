// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { LiquidityService_Base } from "./LiquidityService_Base.t.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// LiquidityService_RemoveLiquidity - unit test for remove liquidity function
// What is this test DONE
//   - remove liquidity
// - revert
//   - remove liquidity when circuit break
//   - remove with zero amount
//   - fail on slippage
// What is this test not covered
// - correctness
//   - remove liquidity of another PLP
//   - remove liquidity with dynamic fee (will be test in Calculator and integration test)
// - revert
//   - PLP transfer in cool down period
contract LiquidityService_RemoveLiquidity is LiquidityService_Base {
  function setUp() public virtual override {
    super.setUp();

    dai.mint(address(this), 100 ether);
    dai.transfer(address(vaultStorage), 100 ether);
    liquidityService.addLiquidity(address(this), address(dai), 100 ether, 0);

    // total supply = 10 ether after add liquidity for ALICE
    // given Total Supply   - 99.7 ether, then TvL = 99.7 e30
    //       unrealized PnL - 0
    //       borrowing fee  - 0
    // aum = tvl + unrealized pnl + borrowing fee = 99.7 e30 + 0 + 0
    mockCalculator.setAUM(99.7e30);
  }

  function testCorrectness_WhenPLPRemoveLiquidity() external {
    liquidityService.removeLiquidity(address(this), address(dai), 50 ether, 0);

    assertEq(plp.totalSupply(), 49.7 ether, "PLP Total Supply");
  }

  // remove liquidity when circuit break
  function testRevert_WhenCircuitBreak_PLPShouldNotRemoveLiquidity() external {
    // disable liquidity config
    IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
    _liquidityConfig.enabled = false;
    configStorage.setLiquidityConfig(_liquidityConfig);

    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityService.removeLiquidity(ALICE, address(dai), 5 ether, 0);
  }

  function testRevert_WhenPLPRemoveLiquidity_WithZeroAmount() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_BadAmount()"));
    liquidityService.removeLiquidity(ALICE, address(dai), 0, 0);
  }

  function testRevert_WhenPLPRemoveLiquidity_AndSlippageCheckFail() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_Slippage()"));
    liquidityService.removeLiquidity(ALICE, address(dai), 5 ether, type(uint256).max);
  }

  // function testRevert_WhenPLPRemoveLiquidity_AfterAddLiquidity_InCoolDownPeriod()
  //   external
  // {}
}
