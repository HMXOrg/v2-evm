// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IConfigStorage, IPerpStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "../../../src/handlers/interfaces/ILimitTradeHandler.sol";

// What is this test DONE
// - revert
//   - Try executing an order when not whitelisted
//   - Try executing a non-existent order
//   - Try executing an order on the market that is currently closed
//   - Try executing an order when price has not reached the trigger price
// - success
//   - Try executing INCREASE and DECREASE order and check that the execution fee is received by the fee receiver

contract LimitTradeHandler_ExecuteOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();

    limitTradeHandler.setOrderExecutor(address(this), true);

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
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

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
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

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
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
  }

  function testRevert_executeOrder_NotWhitelisted() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NotWhitelisted()"));
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  function testRevert_executeOrder_NonExistentOrder() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  function testRevert_executeOrder_MarketIsClosed() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: INCREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(1);
    mockOracle.setPriceStale(false);

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_MarketIsClosed()"));
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  function testRevert_executeOrder_InvalidPriceForExecution() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: INCREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    mockOracle.setPrice(999 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InvalidPriceForExecution()"));
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  function testCorrectness_executeOrder_IncreaseOrder() external {
    // Create Long Increase Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: INCREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });

    // Retrieve Long Increase Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Long Increase Order
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");

    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");

    // Create Short Increase Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: INCREASE,
      _subAccountId: 0,
      _marketIndex: 2,
      _sizeDelta: -1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether
    });
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Execute Short Increase Order
    limitTradeHandler.executeOrder({
      _orderType: INCREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 1);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");

    assertEq(ALICE.balance, 0.2 ether, "Alice should receive execution fee.");
  }

  function testCorrectness_executeOrder_DecreaseOrder() external {
    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 100_000 * 1e30,
        avgEntryPriceE30: 20_000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _orderType: DECREASE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether
    });

    // Retrieve Long Increase Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (
      ,
      limitOrder.account,
      limitOrder.subAccountId,
      limitOrder.marketIndex,
      limitOrder.sizeDelta,
      limitOrder.isLong,
      limitOrder.triggerPrice,
      limitOrder.triggerAboveThreshold,
      limitOrder.executionFee
    ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(999 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Long Decrease Order
    limitTradeHandler.executeOrder({
      _orderType: DECREASE,
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");
  }
}
