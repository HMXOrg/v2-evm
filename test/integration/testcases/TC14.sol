// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

// TC14 - TC15 will include in this case
contract TC14 is BaseIntTest_WithActions {
  function testCorrectness_AddLiquidity_CircuitBreaker() external {
    // T0: Initialized state
    // set circuit breaker
    configStorage.setLiquidityEnabled(false);
    // ALICE NEED 10k in terms of WBTC = 10000 /20000 * 10**8  = 5e7
    uint256 _amount = 5e7;

    // mint 0.5 btc and give 0.0001 gas
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, _amount);

    vm.startPrank(ALICE);
    wbtc.approve(address(liquidityHandler), _amount);
    /// note: minOut always 0 to make test passed
    /// note: shouldWrap treat as false when only GLP could be liquidity
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityHandler.createAddLiquidityOrder{ value: executionOrderFee }(
      address(wbtc),
      _amount,
      0,
      executionOrderFee,
      false
    );
    vm.stopPrank();
  }

  function testCorrectness_RemoveLiquidity_CircuitBreaker() external {
    configStorage.setLiquidityEnabled(false);
    // T0 initial State
    vm.deal(ALICE, executionOrderFee);
    uint256 _amount = 10 ether;
    vm.prank(address(liquidityService));
    plpV2.mint(ALICE, _amount);

    vm.startPrank(ALICE);

    plpV2.approve(address(liquidityHandler), _amount);
    vm.expectRevert(abi.encodeWithSignature("LiquidityService_CircuitBreaker()"));
    liquidityHandler.createRemoveLiquidityOrder{ value: executionOrderFee }(
      address(wbtc),
      _amount,
      0,
      executionOrderFee,
      false
    );
    vm.stopPrank();
  }
}
