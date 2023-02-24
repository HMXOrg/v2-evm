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
//   - Try executing BUY order to create new Long position
//   - Try executing BUY order to increase Long position
//   - Try executing SELL order to create new Short position
//   - Try executing SELL order to increase Short position
//   - Try executing limit order to flip position from Long to Short
//   - Try executing limit order to flip position from Short to Long
//   - Try executing reduce-only limit order to not flip position from Long to Short
//   - Try executing reduce-only limit order to not flip position from Short to Long
//   - Try executing BUY order to partial close Short position
//   - Try executing SELL order to partial close Long position

contract LimitTradeHandler_ExecuteOrder is LimitTradeHandler_Base {
  function setUp() public override {
    super.setUp();

    limitTradeHandler.setOrderExecutor(address(this), true);

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
        exponent: 18,
        maxProfitRate: 9e18,
        minLeverage: 1 * 1e18,
        initialMarginFraction: 0.01 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        priceConfidentThreshold: 0.01 * 1e18,
        allowIncreasePosition: true,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
      })
    );

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
        exponent: 18,
        maxProfitRate: 9e18,
        minLeverage: 1 * 1e18,
        initialMarginFraction: 0.01 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        priceConfidentThreshold: 0.01 * 1e18,
        allowIncreasePosition: true,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
      })
    );

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        assetClass: 1,
        exponent: 18,
        maxProfitRate: 9e18,
        minLeverage: 1 * 1e18,
        initialMarginFraction: 0.01 * 1e18,
        maintenanceMarginFraction: 0.005 * 1e18,
        increasePositionFeeRate: 0,
        decreasePositionFeeRate: 0,
        priceConfidentThreshold: 0.01 * 1e18,
        allowIncreasePosition: true,
        active: true,
        openInterest: IConfigStorage.OpenInterest({
          longMaxOpenInterestUSDE30: 1_000_000 * 1e30,
          shortMaxOpenInterestUSDE30: 1_000_000 * 1e30
        }),
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 0 })
      })
    );
  }

  // Execute an order but the caller is not whitelisted
  function testRevert_executeOrder_NotWhitelisted() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NotWhitelisted()"));
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  // Execute a non-existent order
  function testRevert_executeOrder_NonExistentOrder() external {
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  // Execute an order on the market that is currently closed
  function testRevert_executeOrder_MarketIsClosed() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(1);
    mockOracle.setPriceStale(false);

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_MarketIsClosed()"));
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  // Execute an order when the price has not reached the trigger price
  function testRevert_executeOrder_InvalidPriceForExecution() external {
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    mockOracle.setPrice(999 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InvalidPriceForExecution()"));
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
  }

  // Execute a BUY order to create new Long position
  function testCorrectness_executeOrder_BuyOrder_NewLongPosition() external {
    // Create Buy Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Retrieve Buy Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Long Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");
    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");

    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);
  }

  // Execute a BUY order to create new Long position and create another BUY order to increase it
  function testCorrectness_executeOrder_BuyOrder_IncreaseLongPosition() external {
    // Create Buy Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Retrieve Buy Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Long Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");
    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");

    assertEq(mockTradeService.increasePositionCallCount(), 1);

    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 1000 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Buy Order to increase the same position by 500
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 500 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Long Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    assertEq(mockTradeService.increasePositionCallCount(), 2);

    (_primaryAccount, _subAccountId, _marketIndex, _sizeDelta) = mockTradeService.increasePositionCalls(1);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 500 * 1e30);
  }

  // Execute a SELL order to create new Short position
  function testCorrectness_executeOrder_SellOrder_NewShortPosition() external {
    // Create Sell Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Retrieve Sell Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Short Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");
    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");

    assertEq(mockTradeService.increasePositionCallCount(), 1);

    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -1000 * 1e30);
  }

  // Execute a SELL order to create new Short position and create another SELL order to increase it
  function testCorrectness_executeOrder_SellOrder_IncreaseShortPosition() external {
    // Create Sell Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Retrieve Sell Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(this), "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Short Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });
    (limitOrder.account, , , , , , , , ) = limitTradeHandler.limitOrders(address(this), 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");
    assertEq(ALICE.balance, 0.1 ether, "Alice should receive execution fee.");

    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -1000 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: -1000 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Sell Order to increase the same position by 500
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -500 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Short Increase Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    assertEq(mockTradeService.increasePositionCallCount(), 2);
    (_primaryAccount, _subAccountId, _marketIndex, _sizeDelta) = mockTradeService.increasePositionCalls(1);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -500 * 1e30);
  }

  // Create Long position and flip it with SELL order
  function testCorrectness_executeOrder_FlipLongToShort() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Buy Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 1000 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Sell Order to flip this position
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1500 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be fully closed and a new Short position should be opened
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 1000 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 2);
    (_primaryAccount, _subAccountId, _marketIndex, _sizeDelta) = mockTradeService.increasePositionCalls(1);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -500 * 1e30);
  }

  // Create Short position and flip it with BUY order
  function testCorrectness_executeOrder_FlipShortToLong() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Sell Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1200 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -1200 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: -1200 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Buy Order to flip this position
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be fully closed and a new Long position should be opened
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 1200 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 2);
    (_primaryAccount, _subAccountId, _marketIndex, _sizeDelta) = mockTradeService.increasePositionCalls(1);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 800 * 1e30);
  }

  // Create Long position and create a Reduce-Only with big sizeDelta to see that the position is not flipped
  function testCorrectness_executeOrder_FlipLongToShort_ReduceOnly() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Buy Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 1000 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Sell Order to close this position, but don't flip it due to Reduce-Only
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1500 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be fully closed and a new Short position should not be opened
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 1000 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 1);
  }

  // Create Short position and create a Reduce-Only with big sizeDelta to see that the position is not flipped
  function testCorrectness_executeOrder_FlipShortToLong_ReduceOnly() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Sell Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1200 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -1200 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: -1200 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Buy Order to close this position, but don't flip it due to Reduce-Only
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 2000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: true,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be fully closed and a new Long position should not be opened
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 1200 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 1);
  }

  // Execute a SELL order to partial close a Long position
  function testCorrectness_executeOrder_PartialCloseLongPosition() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Buy Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: 1000 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Sell Order to partial close this position
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -700 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Long position should be partially closed
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 700 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 1);
  }

  // Execute a BUY order to partial close a Short position
  function testCorrectness_executeOrder_PartialCloseShortPosition() external {
    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Create Sell Order
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: -1200 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Sell Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be created
    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (address _primaryAccount, uint256 _subAccountId, uint256 _marketIndex, int256 _sizeDelta) = mockTradeService
      .increasePositionCalls(0);
    assertEq(_primaryAccount, address(this));
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, -1200 * 1e30);

    mockPerpStorage.setPositionBySubAccount(
      address(this),
      IPerpStorage.Position({
        primaryAccount: address(this),
        subAccountId: 0,
        marketIndex: 1,
        positionSizeE30: -1200 * 1e30,
        avgEntryPriceE30: 1000 * 1e30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 9_000 * 1e30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0,
        openInterest: 0
      })
    );

    // Create Buy Order to partial close this position
    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 100 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Execute Buy Order
    limitTradeHandler.executeOrder({
      _account: address(this),
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(ALICE),
      _priceData: new bytes[](0)
    });

    // Short position should be partially closed
    // Assert decrease position call
    assertEq(mockTradeService.decreasePositionCallCount(), 1);
    (
      address _decreaseAccount,
      uint256 _decreaseSubAccountId,
      uint256 _decreaseMarketIndex,
      uint256 _decreasePositionSizeE30ToDecrease
    ) = mockTradeService.decreasePositionCalls(0);
    assertEq(_decreaseAccount, address(this));
    assertEq(_decreaseSubAccountId, 0);
    assertEq(_decreaseMarketIndex, 1);
    assertEq(_decreasePositionSizeE30ToDecrease, 100 * 1e30);

    // Assert increase position call
    assertEq(mockTradeService.increasePositionCallCount(), 1);
  }
}
