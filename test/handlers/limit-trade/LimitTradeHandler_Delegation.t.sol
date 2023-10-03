// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { LimitTradeHandler_Base, IPerpStorage, IConfigStorage } from "./LimitTradeHandler_Base.t.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { LimitOrderTester } from "../../testers/LimitOrderTester.sol";
import { MockAccountAbstraction } from "../../mocks/MockAccountAbstraction.sol";
import { console } from "forge-std/console.sol";

// What is this test DONE
// - revert
//   - Try creating an order will too low execution fee
//   - Try creating an order with incorrect `msg.value`
//   - Try creating an order with sub-account id > 255
//   - Try update an order without being the delegatee
//   - Try cancel an order without being the delegatee
// - success
//   - Try creating BUY and SELL orders and check that the indices of the orders are correct and that all orders are created correctly.

struct Price {
  // Price
  int64 price;
  // Confidence interval around the price
  uint64 conf;
  // Price exponent
  int32 expo;
  // Unix timestamp describing when the price was published
  uint publishTime;
}

// PriceFeed represents a current aggregate price from pyth publisher feeds.
struct PriceFeed {
  // The price ID.
  bytes32 id;
  // Latest available price
  Price price;
  // Latest available exponentially-weighted moving average price
  Price emaPrice;
}

contract LimitTradeHandler_Delegation is LimitTradeHandler_Base {
  bytes[] internal priceData;
  bytes32[] internal priceUpdateData;
  bytes32[] internal publishTimeUpdateData;

  function setUp() public override {
    super.setUp();

    priceData = new bytes[](1);
    priceData[0] = abi.encode(
      PriceFeed({
        id: "1234",
        price: Price({ price: 0, conf: 0, expo: 0, publishTime: block.timestamp }),
        emaPrice: Price({ price: 0, conf: 0, expo: 0, publishTime: block.timestamp })
      })
    );

    limitTradeHandler.setOrderExecutor(address(this), true);

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 1_000_000_000 * 1e30 })
      })
    );

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 1_000_000_000 * 1e30 })
      })
    );

    configStorage.addMarketConfig(
      IConfigStorage.MarketConfig({
        assetId: "A",
        maxLongPositionSize: 10_000_000 * 1e30,
        maxShortPositionSize: 10_000_000 * 1e30,
        assetClass: 1,
        maxProfitRateBPS: 9 * 1e4,
        initialMarginFractionBPS: 0.01 * 1e4,
        maintenanceMarginFractionBPS: 0.005 * 1e4,
        increasePositionFeeRateBPS: 0,
        decreasePositionFeeRateBPS: 0,
        allowIncreasePosition: true,
        active: true,
        fundingRate: IConfigStorage.FundingRate({ maxFundingRate: 0, maxSkewScaleUSD: 1_000_000_000 * 1e30 })
      })
    );
  }

  function testRevert_WhenUpdateOrderWithoutBeingDelegatee() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_Unauthorized()"));
    limitTradeHandler.updateOrder(address(this), 0, 0, 0, 0, 0, true, true, address(0));
    vm.stopPrank();
  }

  function testRevert_WhenCancelOrderWithoutBeingDelegatee() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_Unauthorized()"));
    limitTradeHandler.cancelOrder(address(this), 0, 0);
    vm.stopPrank();
  }

  function testCorrectness_createOrderViaEntryPoint() external {
    vm.startPrank(ALICE);
    MockAccountAbstraction aliceAA = new MockAccountAbstraction(address(entryPoint));
    limitTradeHandler.setDelegate(address(aliceAA));
    vm.stopPrank();

    // Create Buy Order
    mockOracle.setPrice(999 * 1e30);
    entryPoint.createOrder{ value: 0.1 ether }({
      account: address(aliceAA),
      target: address(limitTradeHandler),
      mainAccount: ALICE,
      _subAccountId: 0,
      _marketIndex: 1,
      _sizeDelta: 1000 * 1e30,
      _triggerPrice: 1000 * 1e30,
      _acceptablePrice: 1025 * 1e30, // 1000 * (1 + 0.025) = 1025
      _triggerAboveThreshold: true,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(weth)
    });

    // Retrieve Buy Order that was just created.
    ILimitTradeHandler.LimitOrder memory limitOrder;
    (limitOrder.account, , , , , , , , , , , ) = limitTradeHandler.limitOrders(ALICE, 0);
    assertEq(limitOrder.account, ALICE, "Order should be created.");

    // Mock price to make the order executable
    mockOracle.setPrice(1001 * 1e30);
    mockOracle.setMarketStatus(2);
    mockOracle.setPriceStale(false);

    // Execute Long Increase Order
    address[] memory accounts = new address[](1);
    uint8[] memory subAccountIds = new uint8[](1);
    uint256[] memory orderIndexes = new uint256[](1);
    accounts[0] = ALICE;
    subAccountIds[0] = 0;
    orderIndexes[0] = 0;

    limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(ALICE),
      _priceData: priceUpdateData,
      _publishTimeData: publishTimeUpdateData,
      _minPublishTime: 0,
      _encodedVaas: keccak256("someEncodedVaas")
    });
    (limitOrder.account, , , , , , , , , , , ) = limitTradeHandler.limitOrders(ALICE, 0);
    assertEq(limitOrder.account, address(0), "Order should be executed and removed from the order list.");

    assertEq(mockTradeService.increasePositionCallCount(), 1);
    (
      address _primaryAccount,
      uint8 _subAccountId,
      uint256 _marketIndex,
      int256 _sizeDelta,
      uint256 _limitPriceE30
    ) = mockTradeService.increasePositionCalls(0);
    assertEq(_primaryAccount, ALICE);
    assertEq(_subAccountId, 0);
    assertEq(_marketIndex, 1);
    assertEq(_sizeDelta, 1000 * 1e30);
    assertEq(_limitPriceE30, 1000 * 1e30);
  }
}
