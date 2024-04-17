// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract TradeService_TradingFee is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // Ignore Borrowing fee on this test
    IConfigStorage.AssetClassConfig memory _cryptoConfig = IConfigStorage.AssetClassConfig({ baseBorrowingRate: 0 });
    configStorage.setAssetClassConfigByIndex(0, _cryptoConfig);

    // Ignore Developer fee on this test
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 5 })
    );

    // Set increase/decrease position fee rate to 0.0001%
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(ethMarketIndex);
    _marketConfig.increasePositionFeeRateBPS = 0.0001 * 1e4;
    _marketConfig.decreasePositionFeeRateBPS = 0.0001 * 1e4;
    configStorage.setMarketConfig(ethMarketIndex, _marketConfig, false);
  }

  function testCorrectness_tradingFee_usedOneCollateral() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(weth), 10 * 1e18);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100 * 1e6);

    vm.warp(100);
    {
      // Before ALICE start increases LONG position
      {
        assertEq(vaultStorage.protocolFees(address(weth)), 0);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 10 * 1e18);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);
      }

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      // After ALICE increased LONG position
      {
        // trading Fee = size * increase position fee = 1_000_000 * 0.0001 = 100 USDC
        // trading Fee in WETH amount =  100/1500 = 0.06666666666666667 WETH
        assertEq(vaultStorage.protocolFees(address(weth)), 66666666666666666);
        // Alice WETH's balance after pay trading Fee = 10 - 0.06666666666666667 = 9.933333333333334 WETH;
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 9933333333333333334);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(110);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 600_000 * 1e30, 0);

      // After ALICE increased LONG position
      {
        // trading Fee = size * increase position fee = 600_000 * 0.0001 = 60 USDC
        // trading Fee in WETH amount =  60/1500 = 0.04 WETH
        assertEq(vaultStorage.protocolFees(address(weth)), 66666666666666666 + 40000000000000000); // 0.066 + 0.04 WETH
        // Alice WETH's balance after pay trading Fee = 9.933333333333334 - 0.04 = 9.893333333333334 WETH;
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 9893333333333333334);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }
  }

  function testCorrectness_tradingFee_usedManyCollaterals() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(weth), 0.01 * 1e18);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100_000 * 1e6);

    vm.warp(100);
    {
      // Before ALICE start increases LONG position
      {
        assertEq(vaultStorage.protocolFees(address(weth)), 0);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 0.01 * 1e18);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 100_000 * 1e6);
      }

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 600_000 * 1e30, 0);

      // After ALICE increased LONG position
      {
        // trading Fee = size * increase position fee = 600_000 * 0.0001 = 60 USDC
        // trading Fee in WETH amount =  60/1500 = 0.04 WETH
        // Alice WETH's balance after pay trading fee = 0.01 - 0.04 = 0 WETH;
        assertEq(vaultStorage.traderBalances(aliceAddress, address(weth)), 0);
        assertEq(vaultStorage.protocolFees(address(weth)), 10000000000000000); // 0.01 WETH
        // ALICE USDC's balance after pay trading fee = USDC token - remaining Debt amount  = 100_000 USDC - (0.06666666666666667 - 0.01)*1500 = 100 - 85 = 99955 USDC
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), (100_000 - 45) * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }
  }

  function testCorrectness_tradingFee_WhenDecreasePosition() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1600 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);

    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 100_000 * 1e6);

    vm.warp(100);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      // trading Fee = size * increase position fee = 1_000_000 * 0.0001 = 100 USDC
      // Alice USDT's balance after pay trading fee = 100_000 - 100 = 99_900  USDC;
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 99_900 * 1e6);

      // Ignore Borrowing, Funding, and Dev Fees
      assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
      assertEq(vaultStorage.devFees(address(weth)), 0);
    }

    vm.warp(110);
    {
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, address(0), 0);

      // trading Fee = size * decrease position fee = 500_000 * 0.0001 = 50 USDC
      // Alice USDT's balance after pay trading fee = 99_900 - 50 = 99850  USDC;
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 99850 * 1e6);

      // Ignore Borrowing, Funding, and Dev Fees
      assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
      assertEq(vaultStorage.devFees(address(usdt)), 0);
    }

    vm.warp(120);
    {
      // Close position
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 500_000 * 1e30, address(0), 0);

      // trading Fee = size * decrease position fee = 500_000 * 0.0001 = 50 USDC
      // Alice USDT's balance after pay trading fee = 99850 - 50 = 99800  USDC;
      assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 99800 * 1e6);

      // Ignore Borrowing, Funding, and Dev Fees
      assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
      assertEq(vaultStorage.devFees(address(usdt)), 0);
    }
  }

  function testCorrectness_tradingFee_makerTaker_makerOnly() external {
    uint256[] memory marketIndexes = new uint256[](1);
    marketIndexes[0] = ethMarketIndex;
    uint256[] memory makerFees = new uint256[](1);
    makerFees[0] = 0.0005 * 1e8; // Maker Fee Rate = 0.05%
    uint256[] memory takerFees = new uint256[](1);
    takerFees[0] = 0.001 * 1e8; // Taker Fee Rate = 0.1%
    configStorage.setMakerTakerFeeByMarketIndexes(marketIndexes, makerFees, takerFees);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 15_000 * 1e6);

    vm.warp(100);
    {
      // Before ALICE start increases LONG position
      {
        assertEq(vaultStorage.protocolFees(address(usdt)), 0);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 15_000 * 1e6);
      }

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 1_000_000 * 1e30, 0);

      // Maker Fee Rate = 0.05%
      // Taker Fee Rate = 0.1%

      // After ALICE increased LONG position
      {
        // Alice will be charged with the taker fee on their 1,000,000 size delta, because it made the skew worse.
        // Trading Fee = 1,000,000 * 0.1% = 1,000 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1000 * 1e6);
        // Alice USDT balance after pay trading fee = 15,000 - 1,000 = 14,000 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 14_000 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(110);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 600_000 * 1e30, 0);

      // After ALICE increased LONG position
      {
        // Alice will be charged with the taker fee on their 600,000 size delta, because it made the skew worse.
        // Trading Fee = 600,000 * 0.1% = 600 USDT
        // Previous Protocol Fees = 1,000 USDT
        // Current Protocol Fees = 1,000 + 600 = 1,600 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1600 * 1e6);
        // Alice USDT balance after pay trading fee = 14,000 - 600 = 13,400 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 13_400 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }
  }

  function testCorrectness_tradingFee_makerTaker_makerOnlyButShort() external {
    uint256[] memory marketIndexes = new uint256[](1);
    marketIndexes[0] = ethMarketIndex;
    uint256[] memory makerFees = new uint256[](1);
    makerFees[0] = 0.0005 * 1e8; // Maker Fee Rate = 0.05%
    uint256[] memory takerFees = new uint256[](1);
    takerFees[0] = 0.001 * 1e8; // Taker Fee Rate = 0.1%
    configStorage.setMakerTakerFeeByMarketIndexes(marketIndexes, makerFees, takerFees);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 15_000 * 1e6);

    vm.warp(100);
    {
      // Before ALICE start increases SHORT position
      {
        assertEq(vaultStorage.protocolFees(address(usdt)), 0);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 15_000 * 1e6);
      }

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);

      // Maker Fee Rate = 0.05%
      // Taker Fee Rate = 0.1%

      // After ALICE increased SHORT position
      {
        // Alice will be charged with the taker fee on their 1,000,000 size delta, because it made the skew worse.
        // Trading Fee = 1,000,000 * 0.1% = 1,000 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1000 * 1e6);
        // Alice USDT balance after pay trading fee = 15,000 - 1,000 = 14,000 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 14_000 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(110);
    {
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -600_000 * 1e30, 0);

      // After ALICE increased SHORT position
      {
        // Alice will be charged with the taker fee on their 600,000 size delta, because it made the skew worse.
        // Trading Fee = 600,000 * 0.1% = 600 USDT
        // Previous Protocol Fees = 1,000 USDT
        // Current Protocol Fees = 1,000 + 600 = 1,600 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1600 * 1e6);
        // Alice USDT balance after pay trading fee = 14,000 - 600 = 13,400 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 13_400 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }
  }

  function testCorrectness_tradingFee_makerTaker_makerAndTaker() external {
    uint256[] memory marketIndexes = new uint256[](1);
    marketIndexes[0] = ethMarketIndex;
    uint256[] memory makerFees = new uint256[](1);
    makerFees[0] = 0.0005 * 1e8; // Maker Fee Rate = 0.05%
    uint256[] memory takerFees = new uint256[](1);
    takerFees[0] = 0.001 * 1e8; // Taker Fee Rate = 0.1%
    configStorage.setMakerTakerFeeByMarketIndexes(marketIndexes, makerFees, takerFees);

    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setHLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    mockOracle.setPrice(wethAssetId, 1500 * 1e30);
    // USDT price 1 USD
    mockOracle.setPrice(usdtAssetId, 1 * 1e30);

    address aliceAddress = getSubAccount(ALICE, 0);
    vaultStorage.increaseTraderBalance(aliceAddress, address(usdt), 15_000 * 1e6);

    vm.warp(100);
    {
      // Before ALICE start increases SHORT position
      {
        assertEq(vaultStorage.protocolFees(address(usdt)), 0);
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 15_000 * 1e6);
      }

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -1_000_000 * 1e30, 0);

      // Maker Fee Rate = 0.05%
      // Taker Fee Rate = 0.1%

      // After ALICE increased SHORT position
      {
        // Alice will be charged with the taker fee on their 1,000,000 size delta, because it made the skew worse.
        // Trading Fee = 1,000,000 * 0.1% = 1,000 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1000 * 1e6);
        // Alice USDT balance after pay trading fee = 15,000 - 1,000 = 14,000 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 14_000 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(110);
    {
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 600_000 * 1e30, address(usdt), 0);

      // After ALICE decrease SHORT position
      {
        // Alice will be charged with the maker fee on their 600,000 size delta, because it made the skew better.
        // Trading Fee = 600,000 * 0.05% = 300 USDT
        // Previous Protocol Fees = 1,000 USDT
        // Current Protocol Fees = 1,000 + 300 = 1,300 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1300 * 1e6);
        // Alice USDT balance after pay trading fee = 14,000 - 300 = 13,700 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 13_700 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(120);
    {
      // ALICE will try to flip this position into a LONG position
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 400_000 * 1e30, address(usdt), 0);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, 300_000 * 1e30, 0);

      // After ALICE decrease flip SHORT to LONG position
      {
        // Alice will be charged with the maker fee on their 400,000 size delta, because it made the skew better.
        // And Alice will be charged with the taker fee on their 300,000 size delta, because it made the skew worse.
        // Maker Fee:
        // Trading Fee = 400,000 * 0.05% = 200 USDT
        // Previous Protocol Fees = 1,300 USDT
        // Current Protocol Fees = 1,300 + 200 = 1,500 USDT
        // Taker Fee:
        // Trading Fee = 300,000 * 0.1% = 300 USDT
        // Previous Protocol Fees = 1,500 USDT
        // Current Protocol Fees = 1,500 + 300 = 1,800 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 1800 * 1e6);
        // Alice USDT balance after pay trading fee = 13,700 - 500 = 13,200 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 13_200 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }

    vm.warp(130);
    {
      // ALICE will try to flip this position into a SHORT position
      tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 300_000 * 1e30, address(usdt), 0);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, -500_000 * 1e30, 0);

      // After ALICE decrease flip SHORT to LONG position
      {
        // Alice will be charged with the maker fee on their 300,000 size delta, because it made the skew better.
        // And Alice will be charged with the taker fee on their 500,000 size delta, because it made the skew worse.
        // Maker Fee:
        // Trading Fee = 300,000 * 0.05% = 150 USDT
        // Previous Protocol Fees = 1,800 USDT
        // Current Protocol Fees = 1,800 + 150 = 1,950 USDT
        // Taker Fee:
        // Trading Fee = 500,000 * 0.1% = 500 USDT
        // Previous Protocol Fees = 1,950 USDT
        // Current Protocol Fees = 1,950 + 500 = 2,450 USDT
        assertEq(vaultStorage.protocolFees(address(usdt)), 2450 * 1e6);
        // Alice USDT balance after pay trading fee = 13,200 - 650 = 12,550 USDT
        assertEq(vaultStorage.traderBalances(aliceAddress, address(usdt)), 12_550 * 1e6);

        // Ignore Borrowing, Funding, and Dev Fees
        assertEq(vaultStorage.fundingFeeReserve(address(weth)), 0);
        assertEq(vaultStorage.devFees(address(weth)), 0);
      }
    }
  }
}
