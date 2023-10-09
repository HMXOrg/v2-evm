// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";

contract TC41 is BaseIntTest_WithActions {
  function testCorrectness_TC41_AdaptiveFee() external {
    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    _marketConfig.increasePositionFeeRateBPS = 7;
    _marketConfig.decreasePositionFeeRateBPS = 7;
    configStorage.setMarketConfig(wethMarketIndex, _marketConfig, true);

    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRate: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(
      ALICE,
      ERC20(address(wbtc)),
      100 * 1e8,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 100_000 * 1e6);

    addLiquidity(
      ALICE,
      ERC20(address(usdc)),
      100_000 * 1e6,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    {
      // HLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertHLPTotalSupply(2_094_000 * 1e18);

      // assert HLP
      assertTokenBalanceOf(ALICE, address(hlpV2), 2_094_000 * 1e18);
      assertHLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertHLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    // T2: Open 2 positions in the same market and the same exposure
    {
      // Assert collateral (HLP 100,000 + Collateral 1,000) => 101_000
      assertVaultTokenBalance(address(usdc), 100_000 * 1e6, "TC38: before deposit collateral");
    }

    usdc.mint(BOB, 100_000 * 1e6);
    usdc.mint(CAROL, 100_000 * 1e6);
    depositCollateral(BOB, 0, ERC20(address(usdc)), 100_000 * 1e6);
    depositCollateral(CAROL, 0, ERC20(address(usdc)), 100_000 * 1e6);

    {
      // Assert collateral (HLP 100,000 + Collateral 1,000) => 101_000
      assertVaultTokenBalance(address(usdc), 300_000 * 1e6, "TC38: before deposit collateral");
    }

    int24[] memory askDepthTicks = new int24[](1);
    askDepthTicks[0] = 149149; // 3000094.37572017

    int24[] memory bidDepthTicks = new int24[](1);
    bidDepthTicks[0] = 129149; // 406059.22326026

    int24[] memory coeffVariantTicks = new int24[](1);
    coeffVariantTicks[0] = -60708; // 0.00231002

    bytes32[] memory askDepths = orderbookOracle.buildUpdateData(askDepthTicks);
    bytes32[] memory bidDepths = orderbookOracle.buildUpdateData(bidDepthTicks);
    bytes32[] memory coeffVariants = orderbookOracle.buildUpdateData(coeffVariantTicks);
    orderbookOracle.setUpdater(address(this), true);
    orderbookOracle.updateData(askDepths, bidDepths, coeffVariants);

    assertEq(perpStorage.getEpochOI(true, wethMarketIndex), 0);
    assertEq(perpStorage.getEpochOI(false, wethMarketIndex), 0);

    //  Open position
    // - Long ETHUSD 100,000 USD
    // Adaptive Fee:
    // c = 0.00231002
    // g = 2^(2 - min(1, c))
    // g = 2^(2 - min(1, 0.00231002))
    // g = 2^(2 - 0.00231002) = 3.99360039
    // x = 100000 + (0 * 1.5) = 100000
    // y = 0.0007 + ((min(100000/3000094.37572017, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.03333228, 1))^3.99360039) * 0.05
    // y = 0.0007 + (0.03333228)^3.99360039 * 0.05
    // y = 0.0007 + 0.00000126 * 0.05
    // y = 0.00070006 = 0.070006%
    // in BPS = 0.00070006 * 1e4 = 7 BPS

    // Long ETH
    uint256 usdcProtocolFeeBefore = vaultStorage.protocolFees(address(usdc));
    uint256 usdcDevFeeBefore = vaultStorage.devFees(address(usdc));

    vm.deal(BOB, 1 ether);
    marketBuy(BOB, 0, wethMarketIndex, 100_000 * 1e30, address(usdc), tickPrices, publishTimeDiff, block.timestamp);

    bytes32 _positionId = keccak256(abi.encodePacked(BOB, wethMarketIndex));
    IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 100_000 * 1e30);

    // 0.07% of 100,000 trade = 70 usd in fee
    // 63 usd -> protocol fee
    // 7 usd -> dev fee (10%)
    assertEq(vaultStorage.protocolFees(address(usdc)) - usdcProtocolFeeBefore, 63 * 1e6);
    assertEq(vaultStorage.devFees(address(usdc)) - usdcDevFeeBefore, 7 * 1e6);

    assertEq(perpStorage.getEpochOI(true, wethMarketIndex), 100_000 * 1e30);
    assertEq(perpStorage.getEpochOI(false, wethMarketIndex), 0);

    // Increase position
    // Long ETHUSD 1,500,000 USD
    // Adaptive Fee:
    // c = 0.00231002
    // g = 2^(2 - min(1, c))
    // g = 2^(2 - min(1, 0.00231002))
    // g = 2^(2 - 0.00231002) = 3.99360039
    // x = 1500000 + (100000 * 1.5) = 1650000
    // y = 0.0007 + ((min(1650000/3000094.37572017, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.5499827, 1))^3.99360039) * 0.05
    // y = 0.0007 + (0.5499827)^3.99360039 * 0.05
    // y = 0.0007 + 0.09184548 * 0.05
    // y = 0.00529227 = 0.529227%
    // in BPS = 0.00529227 * 1e4 = 52 BPS
    usdcProtocolFeeBefore = vaultStorage.protocolFees(address(usdc));
    usdcDevFeeBefore = vaultStorage.devFees(address(usdc));
    marketBuy(BOB, 0, wethMarketIndex, 1_500_000 * 1e30, address(usdc), tickPrices, publishTimeDiff, block.timestamp);

    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 1_600_000 * 1e30);

    // 0.52% of 1,500,000 trade = 7800 usd in fee
    // 7,020 usd -> protocol fee
    // 780 usd -> dev fee (10%)
    assertEq(vaultStorage.protocolFees(address(usdc)) - usdcProtocolFeeBefore, 7020 * 1e6);
    assertEq(vaultStorage.devFees(address(usdc)) - usdcDevFeeBefore, 780 * 1e6);

    assertEq(perpStorage.getEpochOI(true, wethMarketIndex), 1_600_000 * 1e30);
    assertEq(perpStorage.getEpochOI(false, wethMarketIndex), 0);

    // Time passed to reset the epochOI
    vm.warp(block.timestamp + 16 minutes);

    assertEq(perpStorage.getEpochOI(true, wethMarketIndex), 0);
    assertEq(perpStorage.getEpochOI(false, wethMarketIndex), 0);

    // Decrese position
    // ETHUSD 100,000 USD
    // Adaptive Fee:
    // c = 0.00231002
    // g = 2^(2 - min(1, c))
    // g = 2^(2 - min(1, 0.00231002))
    // g = 2^(2 - 0.00231002) = 3.99360039
    // x = 100000 + (0 * 1.5) = 100000
    // y = 0.0007 + ((min(100000/406059.22326026, 1))^g) * 0.05
    // y = 0.0007 + ((min(0.2462695, 1))^3.99360039) * 0.05
    // y = 0.0007 + (0.2462695)^3.99360039 * 0.05
    // y = 0.0007 + 0.0037114 * 0.05
    // y = 0.00088557 = 0.088557%
    // in BPS = 0.00088557 * 1e4 = 8 BPS
    usdcProtocolFeeBefore = vaultStorage.protocolFees(address(usdc));
    usdcDevFeeBefore = vaultStorage.devFees(address(usdc));
    marketSell(BOB, 0, wethMarketIndex, 100_000 * 1e30, address(usdc), tickPrices, publishTimeDiff, block.timestamp);

    _position = perpStorage.getPositionById(_positionId);
    assertEq(_position.positionSizeE30, 1_500_000 * 1e30);

    // 0.08% of 100,000 trade = 80 usd in fee
    // 72 usd -> protocol fee
    // 8 usd -> dev fee (10%)
    assertEq(vaultStorage.protocolFees(address(usdc)) - usdcProtocolFeeBefore, 72 * 1e6);
    assertEq(vaultStorage.devFees(address(usdc)) - usdcDevFeeBefore, 8 * 1e6);

    assertEq(perpStorage.getEpochOI(true, wethMarketIndex), 0);
    assertEq(perpStorage.getEpochOI(false, wethMarketIndex), 0);
  }
}