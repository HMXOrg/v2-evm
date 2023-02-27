// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

import { AddressUtils } from "../../../src/libraries/AddressUtils.sol";

// @todo - Test Description
contract TradeService_FudningFee is TradeService_Base {
  using AddressUtils for address;

  function setUp() public virtual override {
    super.setUp();

    // Set PLPLiquidity
    vaultStorage.addPLPLiquidity(configStorage.plpTokens(0), 1000 * 1e18);

    // Set MarginFee to have enough token amounts to repay funding fee
    vaultStorage.addMarginFee(configStorage.plpTokens(0), 10 * 1e18);

    // Set funding rate config
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.fundingRate.maxFundingRate = 4 * 1e14;
    _marketConfig.fundingRate.maxSkewScaleUSD = 3_000_000 * 1e30;

    configStorage.setMarketConfig(ethMarketIndex, _marketConfig);
  }

  function testCorrectness_fundingFee() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(address(weth).toBytes32(), 1600 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.setTraderBalance(aliceAddress, address(weth), 1 * 1e18);
    vaultStorage.setTraderBalance(aliceAddress, address(usdt), 1_000 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
      IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);

      assertEq(_globalAssetClass.sumBorrowingRate, 0);
      assertEq(_globalAssetClass.lastBorrowingTime, 100);

      assertEq(_globalMarket.currentFundingRate, 0);
      assertEq(_globalMarket.accumFundingLong, 0);
      assertEq(_globalMarket.accumFundingShort, 0);

      assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 1 * 1e18);
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 1_000 * 1e6);

      assertEq(vaultStorage.devFees(address(weth)), 0);
      assertEq(vaultStorage.marginFee(address(weth)), 10 * 1e18); // Initial margin fee WETH = 10 WETH
    }

    vm.warp(block.timestamp + 1);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      {
        IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
        IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(0);

        // Long position now must pay 133$ to Short Side
        assertEq(_globalMarket.accumFundingLong, -133333333333333000000); // -133.33$
        assertEq(_globalMarket.accumFundingShort, 0); //

        // Repay WETH Amount = 133.33/1600 = 0.08383958333333312 WETH
        // Dev fee = 0.08383958333333312  * 0.15 = 0.012575937499999967 WETH
        assertEq(vaultStorage.devFees(address(weth)), 12575937499999968);

        // After Alice pay fee, Alice's WETH amount will be decreased
        // Alice's WETH remaining = 1 - 0.08383958333333312 = 0.916160416666666875 WETH
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 0.916160416666666875 * 1e18);

        // Alive already paid all fees
        assertEq(perpStorage.getSubAccountFee(aliceAddress), 0);

        // new marginFee = old marginFee + (fee collect from ALICE - dev Fee) = 10 + ( 0.08383958333333312 - 0.012575937499999967) = 10071263645833333157 WETH
        assertEq(vaultStorage.marginFee(address(weth)), 10071263645833333157);
      }
    }
  }
}
