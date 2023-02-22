// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";
import { PositionTester } from "../../testers/PositionTester.sol";

import { ITradeService } from "../../../src/services/interfaces/ITradeService.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";

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
    tradeService.getDelta(0, size, isLong, avgPriceE30);
  }

  function testCorrectness_getDelta_WhenLongAndPriceUp() external {
    uint256 avgPriceE30 = 22_000 * 1e30;
    uint256 nextPrice = 24_200 * 1e30;
    bool isLong = true;
    uint256 size = 1_000 * 1e30;

    // price up 10% -> profit 10% of size
    mockOracle.setPrice(nextPrice);
    (bool isProfit, uint256 delta) = tradeService.getDelta(0, size, isLong, avgPriceE30);
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
    (bool isProfit, uint256 delta) = tradeService.getDelta(0, size, isLong, avgPriceE30);
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
    (bool isProfit, uint256 delta) = tradeService.getDelta(0, size, isLong, avgPriceE30);
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
    (bool isProfit, uint256 delta) = tradeService.getDelta(0, size, isLong, avgPriceE30);
    assertEq(isProfit, true);
    assertEq(delta, 500 * 1e30);
  }

  ////////////////////////////////////////////////////////////////////////////////////
  /////////////////////  increasePosition FUNCTION  //////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function testRevert_increasePosition_WhenBadSizeDelta() external {
    // Increase Long ETH size 0
    {
      int256 sizeDelta = 0;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadSizeDelta()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
  }

  function testRevert_increasePosition_WhenNotAllowIncreasePosition() external {
    configStorage.setMarketConfig(
      0,
      IConfigStorage.MarketConfig({
        assetId: "ETH",
        assetClass: 0,
        maxProfitRate: 9e18,
        longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
        shortMaxOpenInterestUSDE30: 1_000_000 * 1e30,
        minLeverage: 1,
        initialMarginFraction: 0.01 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        maxFundingRate: 0,
        priceConfidentThreshold: 0.01 * 1e18,
        allowIncreasePosition: false,
        active: true
      })
    );

    // Increase Long ETH size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_NotAllowIncrease()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
    // Increase Long BTC size 1,000,000
    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadNumberOfPosition()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta);
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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
    // Increase Short ETH size 500,000
    {
      int256 sizeDelta = -500_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadExposure()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
  }

  // TODO: Test price revert

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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }

    // Fee collateral decrease 8000 -> 2000 USD
    mockCalculator.setFreeCollateral(2_000 * 1e30);

    // Increase Long BTC size 500,000
    {
      int256 sizeDelta = 500_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta);
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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
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
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }

    // // Fee collateral decrease 8000 -> 2000 USD
    // mockCalculator.setFreeCollateral(2_000 * 1e30);

    // Increase Long BTC size 888,000
    // Reserve value 8,800 * 9 = 79,200
    {
      int256 sizeDelta = 888_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientLiquidity()"));
      tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta);
    }
  }

  function testCorrectness_increasePosition_WhenLongMarket01() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    int256 sizeDelta = 1_000_000 * 1e30;

    bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

    IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

    IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

    assertEq(_positionAfter.primaryAccount, ALICE);
    assertEq(_positionAfter.subAccountId, 0);
    assertEq(_positionAfter.marketIndex, ethMarketIndex);
    assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
    assertEq(_positionAfter.avgEntryPriceE30, price);
    assertEq(_positionAfter.reserveValueE30, 9 * 10_000 * 1e30);
    assertEq(_positionAfter.lastIncreaseTimestamp, 0);
    assertEq(_positionAfter.realizedPnl, 0);
    assertEq(_positionAfter.openInterest, 625 * 1e30);
  }

  function testCorrectness_increasePosition_WhenShortMarket02() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // BTC price 25000 USD
    uint256 price = 25_000 * 1e30;
    mockOracle.setPrice(price);

    int256 sizeDelta = -800_000 * 1e30;

    bytes32 _positionId = getPositionId(ALICE, 0, btcMarketIndex);

    IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

    tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta);

    IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

    assertEq(_positionAfter.primaryAccount, ALICE);
    assertEq(_positionAfter.subAccountId, 0);
    assertEq(_positionAfter.marketIndex, btcMarketIndex);
    assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
    assertEq(_positionAfter.avgEntryPriceE30, price);
    assertEq(_positionAfter.reserveValueE30, 9 * 8_000 * 1e30);
    assertEq(_positionAfter.lastIncreaseTimestamp, 0);
    assertEq(_positionAfter.realizedPnl, 0);
    assertEq(_positionAfter.openInterest, 32 * 1e30);
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

    // ALICE Increase position Long ETH size 500,000
    {
      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

      IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketBefore = perpStorage.getGlobalMarketByIndex(ethMarketIndex);

      int256 sizeDelta = 500_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

      IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketAfter = perpStorage.getGlobalMarketByIndex(ethMarketIndex);

      assertEq(_positionAfter.primaryAccount, ALICE);
      assertEq(_positionAfter.subAccountId, 0);
      assertEq(_positionAfter.marketIndex, ethMarketIndex);
      assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
      assertEq(_positionAfter.avgEntryPriceE30, price);
      assertEq(_positionAfter.reserveValueE30, 9 * 5_000 * 1e30);
      assertEq(_positionAfter.lastIncreaseTimestamp, 0);
      assertEq(_positionAfter.realizedPnl, 0);
      assertEq(_positionAfter.openInterest, 312.5 * 1e30);

      assertEq(_globalMarketAfter.longPositionSize - _globalMarketBefore.longPositionSize, uint256(sizeDelta));
      assertEq(_globalMarketAfter.longOpenInterest - _globalMarketBefore.longOpenInterest, uint256(312.5 * 1e30));
    }

    // ALICE Adjust position Long ETH size 500,000
    {
      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

      IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketBefore = perpStorage.getGlobalMarketByIndex(ethMarketIndex);

      int256 sizeDelta = 400_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

      IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketAfter = perpStorage.getGlobalMarketByIndex(ethMarketIndex);

      assertEq(_positionAfter.primaryAccount, ALICE);
      assertEq(_positionAfter.subAccountId, 0);
      assertEq(_positionAfter.marketIndex, ethMarketIndex);
      assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
      assertEq(_positionAfter.avgEntryPriceE30, price);
      assertEq(_positionAfter.reserveValueE30, 9 * 9_000 * 1e30);
      assertEq(_positionAfter.lastIncreaseTimestamp, 0);
      assertEq(_positionAfter.realizedPnl, 0);
      assertEq(_positionAfter.openInterest, 562.5 * 1e30);

      assertEq(_globalMarketAfter.longPositionSize - _globalMarketBefore.longPositionSize, uint256(sizeDelta));
      assertEq(_globalMarketAfter.longOpenInterest - _globalMarketBefore.longOpenInterest, uint256(250 * 1e30));
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
    uint256 price = 25_00 * 1e30;
    mockOracle.setPrice(price);

    // BOB Increase position Short BTC size 250,000
    {
      bytes32 _positionId = getPositionId(BOB, 0, btcMarketIndex);

      IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketBefore = perpStorage.getGlobalMarketByIndex(btcMarketIndex);

      int256 sizeDelta = -250_000 * 1e30;
      tradeService.increasePosition(BOB, 0, btcMarketIndex, sizeDelta);

      IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketAfter = perpStorage.getGlobalMarketByIndex(btcMarketIndex);

      assertEq(_positionAfter.primaryAccount, BOB);
      assertEq(_positionAfter.subAccountId, 0);
      assertEq(_positionAfter.marketIndex, btcMarketIndex);
      assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
      assertEq(_positionAfter.avgEntryPriceE30, price);
      assertEq(_positionAfter.reserveValueE30, 9 * 2_500 * 1e30);
      assertEq(_positionAfter.lastIncreaseTimestamp, 0);
      assertEq(_positionAfter.realizedPnl, 0);
      assertEq(_positionAfter.openInterest, 100 * 1e30);

      assertEq(_globalMarketAfter.shortPositionSize - _globalMarketBefore.shortPositionSize, uint256(-sizeDelta));
      assertEq(_globalMarketAfter.shortOpenInterest - _globalMarketBefore.shortOpenInterest, 100 * 1e30);
    }

    // BOB Adjust position Short BTC size 750,000
    {
      bytes32 _positionId = getPositionId(BOB, 0, btcMarketIndex);

      IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketBefore = perpStorage.getGlobalMarketByIndex(btcMarketIndex);

      int256 sizeDelta = -750_000 * 1e30;
      tradeService.increasePosition(BOB, 0, btcMarketIndex, sizeDelta);

      IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(_positionId);

      IPerpStorage.GlobalMarket memory _globalMarketAfter = perpStorage.getGlobalMarketByIndex(btcMarketIndex);

      assertEq(_positionAfter.primaryAccount, BOB);
      assertEq(_positionAfter.subAccountId, 0);
      assertEq(_positionAfter.marketIndex, btcMarketIndex);
      assertEq(_positionAfter.positionSizeE30 - _positionBefore.positionSizeE30, sizeDelta);
      assertEq(_positionAfter.avgEntryPriceE30, price);
      assertEq(_positionAfter.reserveValueE30, 9 * 10_000 * 1e30);
      assertEq(_positionAfter.lastIncreaseTimestamp, 0);
      assertEq(_positionAfter.realizedPnl, 0);
      assertEq(_positionAfter.openInterest, 400 * 1e30);

      assertEq(_globalMarketAfter.shortPositionSize - _globalMarketBefore.shortPositionSize, uint256(-sizeDelta));
      assertEq(_globalMarketAfter.shortOpenInterest - _globalMarketBefore.shortOpenInterest, 300 * 1e30);
    }
  }
}
