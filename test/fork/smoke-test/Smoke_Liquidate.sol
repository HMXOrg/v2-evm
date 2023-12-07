// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

import "forge-std/console.sol";

contract Smoke_Liquidate is ForkEnv {
  address[] internal activeSubAccounts;

  // for shorter time
  function liquidate() external {
    (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceDataForReader(1);
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();
    address[] memory liqSubAccounts = new address[](10);

    // NOTE: MUST ignore when it's address(0), filtering is needed.
    liqSubAccounts = ForkEnv.liquidationReader.getLiquidatableSubAccount(10, 0, assetIds, prices, shouldInverts);

    vm.startPrank(ForkEnv.positionManager);
    ForkEnv.botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < 10; i++) {
      if (liqSubAccounts[i] == address(0)) continue;
      ForkEnv.botHandler.liquidate(
        liqSubAccounts[i],
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );
      // Liquidated, no pos left.
      assertEq(ForkEnv.perpStorage.getNumberOfSubAccountPosition(liqSubAccounts[i]), 0);
    }
    ForkEnv.botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }

  function liquidateWithAdaptiveFee() external {
    // Set SOLUSD trade limit
    uint256[] memory _marketIndexes = new uint256[](1);
    _marketIndexes[0] = 21;
    uint256[] memory _positionSizeLimits = new uint256[](1);
    _positionSizeLimits[0] = 1_000_000 * 1e30;
    uint256[] memory _tradeSizeLimits = new uint256[](1);
    _tradeSizeLimits[0] = 1_000_000 * 1e30;
    vm.prank(limitTradeHelper.owner());
    limitTradeHelper.setLimit(_marketIndexes, _positionSizeLimits, _tradeSizeLimits);

    // Mint tokens for Alice and Bob
    deal(address(ForkEnv.usdc_e), ForkEnv.ALICE, 100_000 * 1e6);
    deal(ForkEnv.ALICE, 10 ether);

    deal(address(ForkEnv.usdc_e), ForkEnv.BOB, 100_000 * 1e6);
    deal(ForkEnv.BOB, 10 ether);

    // Alice open $100,000 SOLUSD long position
    vm.startPrank(ForkEnv.ALICE);
    ForkEnv.usdc_e.approve(address(ForkEnv.crossMarginHandler), type(uint256).max);

    uint256 usdcCollateralAmount = 1355 * 1e6;

    ForkEnv.crossMarginHandler.depositCollateral(0, address(ForkEnv.usdc_e), usdcCollateralAmount, false);
    assertEq(ForkEnv.vaultStorage.traderBalances(ForkEnv.ALICE, address(ForkEnv.usdc_e)), usdcCollateralAmount);
    // console.logInt(ForkEnv.calculator.getEquity(ForkEnv.ALICE, 0, ""));

    ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 21,
      _sizeDelta: 100_000 * 1e30,
      _triggerPrice: 0,
      _acceptablePrice: type(uint256).max,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(usdc_e)
    });
    vm.stopPrank();

    IEcoPythCalldataBuilder.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata
    ) = ForkEnv.ecoPythBuilder.build(data);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Alice Order
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = 0;
    address[] memory accounts = new address[](1);
    accounts[0] = ForkEnv.ALICE;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = 0;

    vm.prank(ForkEnv.limitOrderExecutor);
    ForkEnv.limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(ForkEnv.perpStorage.getNumberOfSubAccountPosition(ForkEnv.ALICE), 1);
    // console.logInt(ForkEnv.calculator.getEquity(ForkEnv.ALICE, 0, ""));

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Bob open $300,000 SOLUSD short position to drive the adaptive fee up
    vm.startPrank(ForkEnv.BOB);
    ForkEnv.usdc_e.approve(address(ForkEnv.crossMarginHandler), type(uint256).max);

    ForkEnv.crossMarginHandler.depositCollateral(0, address(ForkEnv.usdc_e), 100_000 * 1e6, false);
    assertEq(ForkEnv.vaultStorage.traderBalances(ForkEnv.BOB, address(ForkEnv.usdc_e)), 100_000 * 1e6);
    // console.logInt(ForkEnv.calculator.getEquity(ForkEnv.BOB, 0, ""));

    ForkEnv.limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 21,
      _sizeDelta: -300_000 * 1e30,
      _triggerPrice: 0,
      _acceptablePrice: 0,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(usdc_e)
    });
    vm.stopPrank();

    // Execute Bob Order
    orderIndexes[0] = 0;
    accounts[0] = ForkEnv.BOB;
    subAccountIds[0] = 0;

    vm.prank(ForkEnv.limitOrderExecutor);
    ForkEnv.limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(ForkEnv.perpStorage.getNumberOfSubAccountPosition(ForkEnv.BOB), 1);

    // Try to liquidate Alice, because Bob should drive the Adaptive Fee up to the point that Alice should be liquidated
    vm.startPrank(ForkEnv.positionManager);
    ForkEnv.botHandler.liquidate(
      ForkEnv.ALICE,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    assertEq(ForkEnv.perpStorage.getNumberOfSubAccountPosition(ForkEnv.ALICE), 0);
    assertEq(ForkEnv.vaultStorage.traderBalances(ForkEnv.ALICE, address(ForkEnv.usdc_e)), 0);
  }
}
