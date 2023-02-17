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

  // function testRevert_getDelta_WhenBadAveragePrice() external {
  //   // Bad position average price
  //   uint256 avgPriceE30 = 0;
  //   bool isLong = true;
  //   uint256 size = 1000e30;

  //   vm.expectRevert(
  //     abi.encodeWithSignature("ITradeService_InvalidAveragePrice()")
  //   );
  //   tradeService.getDelta(0, size, isLong, avgPriceE30);
  // }

  // function testCorrectness_getDelta_long_price_up() external {
  //   uint256 avgPriceE30 = 22000e30;
  //   uint256 nextPrice = 24200e30;
  //   bool isLong = true;
  //   uint256 size = 1000e30;

  //   // price up 10% -> profit 10% of size
  //   mockOracle.setPrice(nextPrice);
  //   (bool isProfit, uint256 delta) = tradeService.getDelta(
  //     0,
  //     size,
  //     isLong,
  //     avgPriceE30
  //   );
  //   assertEq(isProfit, true);
  //   assertEq(delta, 100e30);
  // }

  // function testCorrectness_getDelta_long_price_down() external {
  //   uint256 avgPriceE30 = 22000e30;
  //   uint256 nextPrice = 18700e30;
  //   bool isLong = true;
  //   uint256 size = 1000e30;

  //   // price down 15% -> loss 15% of size
  //   mockOracle.setPrice(nextPrice);
  //   (bool isProfit, uint256 delta) = tradeService.getDelta(
  //     0,
  //     size,
  //     isLong,
  //     avgPriceE30
  //   );
  //   assertEq(isProfit, false);
  //   assertEq(delta, 150e30);
  // }

  // function testCorrectness_getDelta_short_price_up() external {
  //   uint256 avgPriceE30 = 22000e30;
  //   uint256 nextPrice = 23100e30;
  //   bool isLong = false;
  //   uint256 size = 1000e30;

  //   // price up 5% -> loss 5% of size
  //   mockOracle.setPrice(nextPrice);
  //   (bool isProfit, uint256 delta) = tradeService.getDelta(
  //     0,
  //     size,
  //     isLong,
  //     avgPriceE30
  //   );
  //   assertEq(isProfit, false);
  //   assertEq(delta, 50e30);
  // }

  // function testCorrectness_getDelta_short_price_down() external {
  //   uint256 avgPriceE30 = 22000e30;
  //   uint256 nextPrice = 11000e30;
  //   bool isLong = false;
  //   uint256 size = 1000e30;

  //   // price down 50% -> profit 50% of size
  //   mockOracle.setPrice(nextPrice);
  //   (bool isProfit, uint256 delta) = tradeService.getDelta(
  //     0,
  //     size,
  //     isLong,
  //     avgPriceE30
  //   );
  //   assertEq(isProfit, true);
  //   assertEq(delta, 500e30);
  // }

  ////////////////////////////////////////////////////////////////////////////////////
  /////////////////////  increasePosition FUNCTION  ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function testRevert_increasePosition_WhenBadNumberOfPosition() external {
    configStorage.setTradingConfig(
      IConfigStorage.TradingConfig({
        fundingInterval: 1,
        borrowingDevFeeRate: 0,
        minProfitDuration: 0,
        maxPosition: 1
      })
    );
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPlpValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    int256 sizeDelta = 1_000_000 * 1e30;

    tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

    vm.expectRevert(
      abi.encodeWithSignature("ITradeService_BadNumberOfPosition()")
    );
    tradeService.increasePosition(ALICE, 0, btcMarketIndex, sizeDelta);
  }

  function testRevert_increasePosition_WhenBadExposure() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPlpValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    {
      int256 sizeDelta = 1_000_000 * 1e30;
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
    {
      int256 sizeDelta = -500_000 * 1e30;
      vm.expectRevert(abi.encodeWithSignature("ITradeService_BadExposure()"));
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
  }

  function testRevert_increasePosition_WhenInsufficientFreeCollateral()
    external
  {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPlpValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 8000 USDT -> free collateral -> 8000 USD
    mockCalculator.setFreeCollateral(8_000 * 1e30);

    // ETH price 1600 USD
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    {
      int256 sizeDelta = 1_000_000 * 1e30;
      vm.expectRevert(
        abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()")
      );
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }
  }

  // TODO: Test price revert

  // function testCorrectness_increasePosition() external {
  //   // TVL
  //   // 1000000 USDT -> 1000000 USD
  //   mockCalculator.setPlpValue(1_000_000 * 1e30);
  //   // ALICE add collateral
  //   // 10000 USDT -> free collateral -> 10000 USD
  //   mockCalculator.setFreeCollateral(10_000 * 1e30);

  //   // ETH price 1600 USD
  //   uint256 price = 1_600 * 1e30;
  //   mockOracle.setPrice(price);

  //   int256 sizeDelta = 1_000_000 * 1e30;

  //   bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

  //   IPerpStorage.Position memory _positionBefore = perpStorage.getPositionById(
  //     _positionId
  //   );

  //   tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

  //   IPerpStorage.Position memory _positionAfter = perpStorage.getPositionById(
  //     _positionId
  //   );

  //   assertEq(_positionAfter.primaryAccount, ALICE);
  //   assertEq(_positionAfter.subAccountId, 0);
  //   assertEq(_positionAfter.marketIndex, ethMarketIndex);
  //   assertEq(
  //     _positionAfter.positionSizeE30 - _positionBefore.positionSizeE30,
  //     sizeDelta
  //   );
  //   assertEq(_positionAfter.avgEntryPriceE30, price);
  //   assertEq(_positionAfter.reserveValueE30, 9 * 10_000 * 1e30);
  //   assertEq(_positionAfter.lastIncreaseTimestamp, 0);
  //   assertEq(_positionAfter.realizedPnl, 0);
  //   assertEq(_positionAfter.openInterest, 625 * 1e30);
  // }

  // function testRevert_increasePosition_WhenBadSubAccountId() external {
  //   vm.expectRevert(abi.encodeWithSignature("ITradeService_BadSubAccountId()"));
  //   tradeService.increasePosition(ALICE, 888, ethMarketIndex, 1_000_000 * 1e30);
  // }
}
