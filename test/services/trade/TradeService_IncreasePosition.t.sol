// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester02 } from "../../testers/PositionTester02.sol";
import { GlobalMarketTester } from "../../testers/GlobalMarketTester.sol";

import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// @todo - add test desciption + use position tester help to check
// @todo - rename test case

contract TradeService_IncreasePosition is TradeService_Base {
  function setUp() public virtual override {
    super.setUp();
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  getDelta FUNCTION  /////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function testRevert_getDelta_WhenBadAveragePrice() external {
    // Bad position average price
    uint256 avgPriceE30 = 0;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    vm.expectRevert(abi.encodeWithSignature("ITradeService_InvalidAveragePrice()"));
    tradeService.getDelta(size, isLong, 1e30, avgPriceE30);
  }

  function testCorrectness_getDelta_WhenLongAndPriceUp() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 24_200 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // price up 10% -> profit 10% of size
    mockOracle.setPrice(nextPrice);
    (bool isProfit, uint256 delta) = tradeService.getDelta(size, isLong, nextPrice, avgPriceE30);

    assertEq(isProfit, true);
    assertEq(delta, 100 * 1e30);
  }

  function testCorrectness_getDelta_WhenLongAndPriceDown() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 18_700 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // price down 15% -> loss 15% of size
    mockOracle.setPrice(nextPrice);
    (bool isProfit, uint256 delta) = tradeService.getDelta(size, isLong, nextPrice, avgPriceE30);

    assertEq(isProfit, false);
    assertEq(delta, 150 * 1e30);
  }

  function testCorrectness_getDelta_WhenShortAndPriceUp() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 23_100 * 1e30;
    bool isLong = false;
    uint256 size = 1_000 * 1e30;

    // price up 5% -> loss 5% of size
    mockOracle.setPrice(nextPrice);
    (bool isProfit, uint256 delta) = tradeService.getDelta(size, isLong, nextPrice, avgPriceE30);

    assertEq(isProfit, false);
    assertEq(delta, 50 * 1e30);
  }

  function testCorrectness_getDelta_WhenShortAndPriceDown() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 11_000 * 1e30;
    bool isLong = false;
    uint256 size = 1_000 * 1e30;

    // price down 50% -> profit 50% of size
    mockOracle.setPrice(nextPrice);
    (bool isProfit, uint256 delta) = tradeService.getDelta(size, isLong, nextPrice, avgPriceE30);

    assertEq(isProfit, true);
    assertEq(delta, 500 * 1e30);
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
        assetId: "ETH",
        assetClass: 0,
        maxProfitRate: 9e18,
        minLeverage: 1 * 1e18,
        initialMarginFraction: 0.01 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        allowIncreasePosition: false,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
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
      IConfigStorage.TradingConfig({ fundingInterval: 1, devFeeRate: 0, minProfitDuration: 0, maxPosition: 1 })
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

  function testRevert_increasePosition_WhenInsufficientFreeCollateral_OnePosition() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 8000 USDT -> free collateral -> 8000 USD
    mockCalculator.setFreeCollateral(8_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    // Increase Long ETH size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }
  }

  function testRevert_increasePosition_WhenInsufficientFreeCollateral_TwoPosition() external {
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

    // Increase Long ETH size 800,000
    {
      int256 sizeDelta = 800_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 0);
    }

    // Fee collateral decrease 8000 -> 2000 USD
    mockCalculator.setFreeCollateral(2_000 * 1e30);

    // Increase Long BTC size 500,000
    {
      int256 sizeDelta = 500_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta, 0);
    }
  }

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
    // openInterest: 625
    //   | 1,000,000 / 1,600 = 625 ETH
    PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
      size: 1_000_000 * 1e30,
      avgPrice: 1_600 * 1e30,
      reserveValue: 90_000 * 1e30,
      lastIncreaseTimestamp: 100,
      openInterest: 625 * 1e18
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
    mockOracle.setExponent(-8);

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
    // openInterest: 32
    //   | 1,000,000 / 25,000 = 32 BTC
    PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
      size: -800_000 * 1e30,
      avgPrice: 25_000 * 1e30,
      reserveValue: 72_000 * 1e30,
      lastIncreaseTimestamp: 100,
      openInterest: 32 * 1e8
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
      // openInterest: 312.5
      //   | 500,000 / 1,600 = 312.5 ETH
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: 500_000 * 1e30,
        avgPrice: 1_600 * 1e30,
        reserveValue: 45_000 * 1e30,
        lastIncreaseTimestamp: 100,
        openInterest: 312.5 * 1e18
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 500,000
      //   | increase position Long 500,000
      // longAvgPrice: 1,600
      //   | price ETH 1,600
      // longOpenInterest: 312.5
      //   | 500,000 / 1,600 = 312.5 ETH
      // shortPositionSize: 0,
      // shortAvgPrice: 0,
      // shortOpenInterest: 0
      GlobalMarketTester.AssertData memory globalMarketAssetData = GlobalMarketTester.AssertData({
        longPositionSize: 500_000 * 1e30,
        longAvgPrice: 1_600 * 1e30,
        longOpenInterest: 312.5 * 1e18,
        shortPositionSize: 0,
        shortAvgPrice: 0,
        shortOpenInterest: 0
      });
      globalMarketTester.assertGlobalMarket(0, globalMarketAssetData);
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
      // openInterest: 312.5
      //   | 400,000 / 1,600 = 250 ETH
      //   | 312.5 + 250 = 562.5
      PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
        size: 900_000 * 1e30,
        avgPrice: 1_600 * 1e30,
        reserveValue: 81_000 * 1e30,
        lastIncreaseTimestamp: 100,
        openInterest: 562.5 * 1e18
      });
      positionTester02.assertPosition(_positionId, assetData);

      // Calculate assert data
      // longPositionSize: 900,000
      //   | increase position Long 400,000
      //   | 500,000 + 400,000 = 900,000
      // longAvgPrice: 1,600
      //   | price ETH 1,600
      // longOpenInterest: 562.5
      //   | 400,000 / 1,600 = 250 ETH
      //   | 312.5 + 250 = 562.5
      // shortPositionSize: 0,
      // shortAvgPrice: 0,
      // shortOpenInterest: 0
      GlobalMarketTester.AssertData memory globalMarketAssetData = GlobalMarketTester.AssertData({
        longPositionSize: 900_000 * 1e30,
        longAvgPrice: 1_600 * 1e30,
        longOpenInterest: 562.5 * 1e18,
        shortPositionSize: 0,
        shortAvgPrice: 0,
        shortOpenInterest: 0
      });
      globalMarketTester.assertGlobalMarket(0, globalMarketAssetData);
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
    mockOracle.setExponent(-8);

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
      // openInterest: 10
      //   | 250,000 / 25,000 = 10 BTC
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: -250_000 * 1e30,
        avgPrice: 25_000 * 1e30,
        reserveValue: 22_500 * 1e30,
        lastIncreaseTimestamp: 100,
        openInterest: 10 * 1e8
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 0
      // longAvgPrice: 0
      // longOpenInterest: 0
      // shortPositionSize: 250,000
      //   | increase position Short 250,000
      // shortAvgPrice: 25,000
      //   | price BTC 25,000
      // shortOpenInterest: 10
      //   | 250,000 / 25,000 = 10 BTC
      GlobalMarketTester.AssertData memory globalMarketAssertData = GlobalMarketTester.AssertData({
        longPositionSize: 0,
        longAvgPrice: 0,
        longOpenInterest: 0,
        shortPositionSize: 250_000 * 1e30,
        shortAvgPrice: 25_000 * 1e30,
        shortOpenInterest: 10 * 1e8
      });
      globalMarketTester.assertGlobalMarket(1, globalMarketAssertData);
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
      // openInterest: 40
      //   | 750,000 / 25,000 = 30 BTC
      //   | 10 + 30 = 40
      PositionTester02.PositionAssertionData memory positionAssetData = PositionTester02.PositionAssertionData({
        size: -1_000_000 * 1e30,
        avgPrice: 25_000 * 1e30,
        reserveValue: 90_000 * 1e30,
        lastIncreaseTimestamp: 100,
        openInterest: 40 * 1e8
      });
      positionTester02.assertPosition(_positionId, positionAssetData);

      // Calculate assert data
      // longPositionSize: 0
      // longAvgPrice: 0
      // longOpenInterest: 0
      // shortPositionSize: 1,000,000
      //   | increase position Short 750,000
      //   | 250,000 + 750,000 = 1,000,000
      // shortAvgPrice: 25,000
      //   | price BTC 25,000
      // shortOpenInterest: 40
      //   | 750,000 / 25,000 = 30 BTC
      //   | 10 + 30 = 40
      GlobalMarketTester.AssertData memory globalMarketAssertData = GlobalMarketTester.AssertData({
        longPositionSize: 0,
        longAvgPrice: 0,
        longOpenInterest: 0,
        shortPositionSize: 1_000_000 * 1e30,
        shortAvgPrice: 25_000 * 1e30,
        shortOpenInterest: 40 * 1e8
      });
      globalMarketTester.assertGlobalMarket(1, globalMarketAssertData);
    }
  }

  function testCorrectness_increasePosition_WhenUsingLimitPrice() external {
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
    // derivedPrice to 1000
    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta, 1_000 * 1e30);

    // Calculate assert data
    // size: 1,000,000
    //   | increase position Long 1,000,000
    // avgPrice: 1,000 (limitPrice 1000, currentPrice 1600)
    //   | price ETH 1,000
    // reserveValue: 90,000
    //   | imr = 1,000,000 * 0.01 = 10,000
    //   | reserve 900% = 10,000 * 900% = 90,000
    // lastIncreaseTimestamp: 100
    //   | increase time 100
    // realizedPnl: 0
    //   | new position
    // openInterest: 1000 (derived interest)
    //   | 1,000,000 / 1,000 = 1000 ETH
    PositionTester02.PositionAssertionData memory assetData = PositionTester02.PositionAssertionData({
      size: 1_000_000 * 1e30,
      avgPrice: 1_000 * 1e30,
      reserveValue: 90_000 * 1e30,
      lastIncreaseTimestamp: 100,
      openInterest: 1_000 * 1e18
    });
    positionTester02.assertPosition(_positionId, assetData);

    (uint256 _price, uint256 _lastUpdate, uint8 _status) = mockOracle.unsafeGetLatestPriceWithMarketStatus(0, false);
    assertEq(_price, 1600 * 1e30);
  }
}
