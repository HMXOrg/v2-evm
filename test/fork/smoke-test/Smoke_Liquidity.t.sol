// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";

import "forge-std/console.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Smoke_Liquidity is Smoke_Base {
  ITradingStaking internal hlpStaking = ITradingStaking(0xbE8f8AF5953869222eA8D39F1Be9d03766010B1C);

  function setUp() public virtual override {
    super.setUp();

  }

  function test_add_liquidity_fork() external {
    _createAddLiquidityOrder();
  }

  function test_remove_liquidity_fork() external {
    _createRemoveLiquidityOrder();
  }

  function _createAddLiquidityOrder() internal {
    deal(address(ForkEnv.usdc_e), ALICE, 10 * 1e6);
    deal(ALICE, 10 ether);
    deal(address(ForkEnv.liquidityHandler), 100 ether);

    vm.startPrank(ALICE);

    ForkEnv.usdc_e.approve(address(ForkEnv.liquidityHandler), type(uint256).max);

    uint256 minExecutionFee = ForkEnv.liquidityHandler.minExecutionOrderFee();

    uint256 _latestOrderIndex = ForkEnv.liquidityHandler.createAddLiquidityOrder{ value: minExecutionFee }(
      address(ForkEnv.usdc_e),
      10 * 1e6,
      0 ether,
      minExecutionFee,
      false
    );
    vm.stopPrank();

    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    vm.prank(address(0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E));
    ForkEnv.liquidityHandler.executeOrder(_latestOrderIndex, payable(ALICE), _priceUpdateCalldata, _publishTimeUpdateCalldata, _minPublishTime, keccak256("someEncodedVaas"));

    assertApproxEqRel(
      hlpStaking.calculateShare(address(this), address(ALICE)),
      10 * ForkEnv.hlp.totalSupply() * 1e30 / calculator.getAUME30(false),
      0.01 ether,
       "User HLP Balance in Staking"
    );
    assertEq(ForkEnv.usdc_e.balanceOf(ALICE), 0, "User USDC.e Balance");
  }

  function _createRemoveLiquidityOrder() internal {
    deal(address(ForkEnv.hlp), ALICE, 10 * 1e18);
    deal(ALICE, 10 ether);
    deal(address(ForkEnv.liquidityHandler), 100 ether);

    vm.startPrank(ALICE);

    ForkEnv.hlp.approve(address(ForkEnv.liquidityHandler), type(uint256).max);

    uint256 minExecutionFee = ForkEnv.liquidityHandler.minExecutionOrderFee();

    uint256 _latestOrderIndex = ForkEnv.liquidityHandler.createRemoveLiquidityOrder{ value: minExecutionFee }(
      address(ForkEnv.usdc_e),
      10 * 1e18,
      0 ether,
      minExecutionFee,
      false
    );
    vm.stopPrank();

    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ecoPythBuilder.build(data);

    vm.prank(address(0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E));
    ForkEnv.liquidityHandler.executeOrder(_latestOrderIndex, payable(ALICE), _priceUpdateCalldata, _publishTimeUpdateCalldata, _minPublishTime, keccak256("someEncodedVaas"));
    
    assertApproxEqRel(
      ForkEnv.usdc_e.balanceOf(ALICE),
      10 * calculator.getAUME30(false) * 1e18 * 1e6 / 1e30 / ForkEnv.hlp.totalSupply(),
      0.01 ether,
       "User USDC.e Balance"
    );
    assertEq(ForkEnv.hlp.balanceOf(ALICE), 0, "User HLP Balance");
  }
}
