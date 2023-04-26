// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { MarketTester } from "../../testers/MarketTester.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { MockCalculatorWithRealCalculator } from "../../mocks/MockCalculatorWithRealCalculator.sol";

contract TradeService_IncreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();

    // Override the mock calculator
    {
      mockCalculator = new MockCalculatorWithRealCalculator(
        address(proxyAdmin),
        address(mockOracle),
        address(vaultStorage),
        address(perpStorage),
        address(configStorage)
      );
      MockCalculatorWithRealCalculator(address(mockCalculator)).useActualFunction("calculateMarketAveragePrice");
      configStorage.setCalculator(address(mockCalculator));
      tradeService.reloadConfig();
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////
  /////////////////////  increasePosition FUNCTION  //////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function testRevert_increasePosition_WhenNotHandlerCall() external {
    int256 sizeDelta = 1_000_000 * 1e30;
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotWhiteListed()"));
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
  }

  function testRevert_increasePosition_WhenBadSizeDelta() external {
    // Increase Long ETH size 0
    {
      int256 sizeDelta = 0;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadSizeDelta()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
  }

  function testRevert_increasePosition_WhenNotAllowIncreasePosition() external {
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: wethAssetId,
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 0,
        maxProfitRateBPS: 9 * 1e4,
        minLeverageBPS: 1 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: false,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
      })
    );

    // Increase Long ETH size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_NotAllowIncrease()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
  }

  function testRevert_increasePosition_WhenBadNumberOfPosition() external {
    // Set max position 1
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRateBPS: 0, minProfitDuration: 0, maxPosition: 1 })
    );
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    {
      uint256 price = 1_600 * 1e30;
      mockOracle.setPrice(price);
    }

    // BTC price 24000 USD
    {
      uint256 price = 24_000 * 1e30;
      mockOracle.setPrice(price);
    }

    // Increase Long ETH size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
    // Increase Long BTC size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadNumberOfPosition()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);
    }
  }

  function testRevert_increasePosition_WhenBadExposure() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // Increase Long ETH size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
    // Increase Short ETH size 500,000
    {
      int256 sizeDelta = -500_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadExposure()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
  }

  // @todo - Test price revert

  function testRevert_increasePosition_WhenITradeService_InsufficientLiquidity_OnePosition() external {
    // TVL
    // 10000 USDT -> 10000 USD
    mockCalculator.setPLPValue(10_000 * 1e30);
    // ALICE add collateral
    // 20000 USDT -> free collateral -> 20000 USD
    mockCalculator.setFreeCollateral(20_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // Increase Long ETH size 2,000,000
    {
      int256 sizeDelta = 2_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientLiquidity()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
  }

  function testRevert_increasePosition_WhenITradeService_InsufficientLiquidity_TwoPosition() external {
    // TVL
    // 16800 USDT -> 168000 USD
    mockCalculator.setPLPValue(168_000 * 1e30);
    // ALICE add collateral
    // 20000 USDT -> free collateral -> 20000 USD
    mockCalculator.setFreeCollateral(20_000 * 1e30);

    // ETH price 1600 USD
    {
      uint256 price = 1_600 * 1e30;
      mockOracle.setPrice(price);
    }

    // BTC price 24000 USD
    {
      uint256 price = 24_000 * 1e30;
      mockOracle.setPrice(price);
    }

    // Increase Long ETH size 1,000,000
    // Reserve value 10,000 * 9 = 90,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }

    // // Fee collateral decrease 8000 -> 2000 USD
    // mockCalculator.setFreeCollateral(2_000 * 1e30);

    // Increase Long BTC size 888,000
    // Reserve value 8,800 * 9 = 79,200
    {
      int256 sizeDelta = 888_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientLiquidity()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);
    }
  }

  function testCorrectness_increasePosition_WhenLongMarket01() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = 1_000_000 * 1e30;
    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

    vm.warp(100);
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);

    // Calculate assert data
    // size: 1,000,000
    //   | increase position Long 1,000,000
    // avgPrice: 1,600
    //   | price ETH 1,600
    // reserveValue: 90,000
    //   | imr = 1,000,000 * 0.01 = 10,000
    //   | reserve 900% = 10,000 * 900% = 90,000
    // lastIncreaseTimestamp: 100
    //   | increase time 100
    // realizedPnl: 0
    //   | new position
    PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
      size: 1_000_000 * 1e30,
      avgPrice: 1_600 * 1e30,
      reserveValue: 90_000 * 1e30,
      lastIncreaseTimestamp: 100
    });
    positionTester02.assertPosition(_positionId, assetData);
  }

  function testCorrectness_increasePosition_WhenShortMarket02() external {
    // setup
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // BTC price 25000 USD
    uint256 price = 25_000 * 1e30;
    mockOracle.setPrice(price);

    // input
    int256 sizeDelta = -800_000 * 1e30;
    bytes32 _positionId = getPositionId(ALICE, 0, btcMarketIndex);

    vm.warp(100);
    tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);

    // Calculate assert data
    // size: -800,000
    //   | increase position Short 800,000
    // avgPrice: 25,000
    //   | price BTC 25,000
    // reserveValue: 72,000
    //   | imr = 800,000 * 0.01 = 8,000
    //   | reserve 900% = 8,000 * 900% = 72,000
    // lastIncreaseTimestamp: 100
    //   | increase time 100
    // realizedPnl: 0
    //   | new position
    PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
      size: -800_000 * 1e30,
      avgPrice: 25_000 * 1e30,
      reserveValue: 72_000 * 1e30,
      lastIncreaseTimestamp: 100
    });
    positionTester02.assertPosition(_positionId, assetData);
  }

  function testCorrectness_increasePosition_WhenIncreaseAndAdjustLongMarket01() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    vm.warp(100);
    // ALICE Increase position Long ETH size 500,000
    {
      int256 sizeDelta = 500_000 * 1e30;
      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);

      // Calculate assert data
      // size: 500,000
      //   | increase position Long 500,000
      // avgPrice: 1,600
      //   | price ETH 1,600
      // reserveValue: 45,000
      //   | imr = 500,000 * 0.01 = 5,000
      //   | reserve 900% = 5,000 * 900% = 45,000
      // lastIncreaseTimestamp: 100
      //   | increase time 100
      // realizedPnl: 0
      //   | new position
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: 500_000 * 1e30,
        avgPrice: 1_600 * 1e30,
        reserveValue: 45_000 * 1e30,
        lastIncreaseTimestamp: 100
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 500,000
      //   | increase position Long 500,000
      // longAvgPrice: 1,600
      //   | price ETH 1,600
      // shortPositionSize: 0,
      // shortAvgPrice: 0,
      MarketTester.AssertData memory globalMarketAssetData = MarketTester.AssertData({
        longPositionSize: 500_000 * 1e30,
        longAvgPrice: 1_600 * 1e30,
        shortPositionSize: 0,
        shortAvgPrice: 0
      });
      globalMarketTester.assertMarket(0, globalMarketAssetData);
    }

    // ALICE Adjust position Long ETH size 400,000
    {
      int256 sizeDelta = 400_000 * 1e30;
      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);

      // Calculate assert data
      // size: 900,000
      //   | increase position Long 400,000
      //   | 500,000 + 400,000 = 900,000
      // avgPrice: 1,600
      //   | price ETH 1,600
      // reserveValue: 81,000
      //   | imr = 900,000 * 0.01 = 9,000
      //   | reserve 900% = 9,000 * 900% = 81,000
      // lastIncreaseTimestamp: 100
      //   | increase time 100
      // realizedPnl: 0
      //   | new position
      PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
        size: 900_000 * 1e30,
        avgPrice: 1_600 * 1e30,
        reserveValue: 81_000 * 1e30,
        lastIncreaseTimestamp: 100
      });
      positionTester02.assertPosition(_positionId, assetData);

      // Calculate assert data
      // longPositionSize: 900,000
      //   | increase position Long 400,000
      //   | 500,000 + 400,000 = 900,000
      // longAvgPrice: 1,600
      //   | price ETH 1,600
      // shortPositionSize: 0,
      // shortAvgPrice: 0,
      MarketTester.AssertData memory globalMarketAssetData = MarketTester.AssertData({
        longPositionSize: 900_000 * 1e30,
        longAvgPrice: 1_600 * 1e30,
        shortPositionSize: 0,
        shortAvgPrice: 0
      });
      globalMarketTester.assertMarket(0, globalMarketAssetData);
    }
  }

  function testCorrectness_increasePosition_WhenIncreaseAndAdjustShortMarket02() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // BTC price 25,000 USD
    uint256 price = 25_000 * 1e30;
    mockOracle.setPrice(price);
    // mockOracle.setExponent(-8);

    vm.warp(100);
    // BOB Increase position Short BTC size 250,000
    {
      int256 sizeDelta = -250_000 * 1e30;
      bytes32 _positionId = getPositionId(BOB, 0, btcMarketIndex);
      tradeService.increasePosition(BOB, 0, btcMarketIndex, sizeDelta, 0);

      // Calculate assert data
      // size: -250,000
      //   | increase position Short 250,000
      // avgPrice: 25,000
      //   | price BTC 25,000
      // reserveValue: 22,500
      //   | imr = 250,000 * 0.01 = 2,500
      //   | reserve 900% = 2,500 * 900% = 22,500
      // lastIncreaseTimestamp: 100
      //   | increase time 100
      // realizedPnl: 0
      //   | new position
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: -250_000 * 1e30,
        avgPrice: 25_000 * 1e30,
        reserveValue: 22_500 * 1e30,
        lastIncreaseTimestamp: 100
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 0
      // longAvgPrice: 0
      // shortPositionSize: 250,000
      //   | increase position Short 250,000
      // shortAvgPrice: 25,000
      //   | price BTC 25,000
      MarketTester.AssertData memory globalMarketAssertData = MarketTester.AssertData({
        longPositionSize: 0,
        longAvgPrice: 0,
        shortPositionSize: 250_000 * 1e30,
        shortAvgPrice: 25_000 * 1e30
      });
      globalMarketTester.assertMarket(1, globalMarketAssertData);
    }

    // BOB Adjust position Short BTC size 750,000
    {
      int256 sizeDelta = -750_000 * 1e30;
      bytes32 _positionId = getPositionId(BOB, 0, btcMarketIndex);
      tradeService.increasePosition(BOB, 0, btcMarketIndex, sizeDelta, 0);

      // Calculate assert data
      // size: -1,000,000
      //   | increase position Short 750,000
      //   | 250,000 + 750,000 = 1,000,000
      // avgPrice: 25,000
      //   | price BTC 25,000
      // reserveValue: 22,500
      //   | imr = 1,000,000 * 0.01 = 10,000
      //   | reserve 900% = 10,000 * 900% = 90,000
      // lastIncreaseTimestamp: 100
      //   | increase time 100
      // realizedPnl: 0
      //   | new position
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: -1_000_000 * 1e30,
        avgPrice: 25_000 * 1e30,
        reserveValue: 90_000 * 1e30,
        lastIncreaseTimestamp: 100
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 0
      // longAvgPrice: 0
      // shortPositionSize: 1,000,000
      //   | increase position Short 750,000
      //   | 250,000 + 750,000 = 1,000,000
      // shortAvgPrice: 25,000
      //   | price BTC 25,000
      MarketTester.AssertData memory globalMarketAssertData = MarketTester.AssertData({
        longPositionSize: 0,
        longAvgPrice: 0,
        shortPositionSize: 1_000_000 * 1e30,
        shortAvgPrice: 25_000 * 1e30
      });
      globalMarketTester.assertMarket(1, globalMarketAssertData);
    }
  }

  function testRevert_WhenIncreasePositionExceedMaxPositionSize() external {
    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionSizeExceed()"));
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, 12_000_000 * 1e30, 0);

    vm.expectRevert(abi.encodeWithSignature("ITradeService_PositionSizeExceed()"));
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, -int256(12_000_000 * 1e30), 0);
  }
}
