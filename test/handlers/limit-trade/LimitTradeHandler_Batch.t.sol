// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LimitTradeHandler_Base } from "@hmx-test/handlers/limit-trade/LimitTradeHandler_Base.t.sol";
import { LimitOrderTester } from "@hmx-test/testers/LimitOrderTester.sol";

import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract LimitTradeHandler_Batch is LimitTradeHandler_Base {
  bytes[] internal priceData;
  bytes32[] internal priceUpdateData;
  bytes32[] internal publishTimeUpdateData;

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

  function testRevert_WhenExecutionFeeNotMatchWithMsgValue() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](2);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Create;

    bytes[] memory _datas = new bytes[](2);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));
    _datas[1] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_InsufficientExecutionFee()"));
    limitTradeHandler.batch{ value: 10 ether }(address(this), _cmds, _datas);
  }

  function testRevert_WhenBatchWithoutBeingDelegatee() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](2);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Create;

    bytes[] memory _datas = new bytes[](2);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));
    _datas[1] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));

    vm.deal(ALICE, 100 ether);
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_Unauthorized()"));
    limitTradeHandler.batch{ value: 2 ether }(address(this), _cmds, _datas);
  }

  function testRevert_WhenUpdateNonExistedOrder() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](1);
    _cmds[0] = ILimitTradeHandler.Command.Update;

    bytes[] memory _datas = new bytes[](1);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, true, true, address(1));

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.batch(address(this), _cmds, _datas);
  }

  function testRevert_WhenUpdateOrderWithZeroSizeDelta() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](2);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Update;

    bytes[] memory _datas = new bytes[](2);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1_000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));
    _datas[1] = abi.encode(0, 0, 0, 0, true, true, address(1));

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_BadSizeDelta()"));
    limitTradeHandler.batch{ value: 1 ether }(address(this), _cmds, _datas);
  }

  function testRevert_WhenUpdateMarketOrder() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](2);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Update;

    bytes[] memory _datas = new bytes[](2);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 0, 800 * 1e30, true, 1 ether, true, address(1));
    _datas[1] = abi.encode(0, 0, 50 * 1e30, 0, true, true, address(1));

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_MarketOrderNoUpdate()"));
    limitTradeHandler.batch{ value: 1 ether }(address(this), _cmds, _datas);
  }

  function testRevert_WhenConvertLimitOrderToMarketOrder() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](2);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Update;

    bytes[] memory _datas = new bytes[](2);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 1 ether, true, address(1));
    _datas[1] = abi.encode(0, 0, 50 * 1e30, 0, true, false, address(1));

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_LimitOrderConvertToMarketOrder()"));
    limitTradeHandler.batch{ value: 1 ether }(address(this), _cmds, _datas);
  }

  function testRevert_WhenCancelNonExistedOrder() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](1);
    _cmds[0] = ILimitTradeHandler.Command.Cancel;

    bytes[] memory _datas = new bytes[](1);
    _datas[0] = abi.encode(0, 0);

    vm.expectRevert(abi.encodeWithSignature("ILimitTradeHandler_NonExistentOrder()"));
    limitTradeHandler.batch(address(this), _cmds, _datas);
  }

  function testCorrectness_WhenCreateMultipleOrders() external {
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](3);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Create;
    _cmds[2] = ILimitTradeHandler.Command.Create;

    bytes[] memory _datas = new bytes[](3);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));
    _datas[1] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));
    _datas[2] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));

    limitTradeHandler.batch{ value: 0.3 ether }(address(this), _cmds, _datas);

    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 3, "limitOrdersIndex should increase by three.");
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: true,
        sizeDelta: 100 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 800 * 1e30,
        executionFee: 0.1 ether
      })
    });
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: true,
        sizeDelta: 100 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 800 * 1e30,
        executionFee: 0.1 ether
      })
    });
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: true,
        sizeDelta: 100 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 800 * 1e30,
        executionFee: 0.1 ether
      })
    });
  }

  function testCorrectness_WhenCreateUpdateCanel() external {
    // Create 3 orders
    ILimitTradeHandler.Command[] memory _cmds = new ILimitTradeHandler.Command[](3);
    _cmds[0] = ILimitTradeHandler.Command.Create;
    _cmds[1] = ILimitTradeHandler.Command.Create;
    _cmds[2] = ILimitTradeHandler.Command.Create;

    bytes[] memory _datas = new bytes[](3);
    _datas[0] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));
    _datas[1] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));
    _datas[2] = abi.encode(0, 0, 100 * 1e30, 1000 * 1e30, 800 * 1e30, true, 0.1 ether, true, address(weth));

    limitTradeHandler.batch{ value: 0.3 ether }(address(this), _cmds, _datas);

    // Update #1 and #2 orders, Cancel #3 orders
    _cmds = new ILimitTradeHandler.Command[](3);
    _cmds[0] = ILimitTradeHandler.Command.Update;
    _cmds[1] = ILimitTradeHandler.Command.Update;
    _cmds[2] = ILimitTradeHandler.Command.Cancel;

    _datas = new bytes[](3);
    _datas[0] = abi.encode(0, 0, 50 * 1e30, 1000 * 1e30, true, true, address(weth));
    _datas[1] = abi.encode(0, 1, 10 * 1e30, 1000 * 1e30, true, true, address(weth));
    _datas[2] = abi.encode(0, 2);

    uint256 _balanceBefore = address(this).balance;
    limitTradeHandler.batch(address(this), _cmds, _datas);
    uint256 _balanceAfter = address(this).balance;

    assertEq(limitTradeHandler.limitOrdersIndex(address(this)), 3, "limitOrdersIndex should be 3");
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 0,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: true,
        sizeDelta: 50 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 800 * 1e30,
        executionFee: 0.1 ether
      })
    });
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 1,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(this),
        tpToken: address(weth),
        triggerAboveThreshold: true,
        reduceOnly: true,
        sizeDelta: 10 * 1e30,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 1000 * 1e30,
        acceptablePrice: 800 * 1e30,
        executionFee: 0.1 ether
      })
    });
    assertEq(_balanceAfter - _balanceBefore, 0.1 ether, "should get execution fee back");
    limitOrderTester.assertLimitOrder({
      _subAccount: address(this),
      _orderIndex: 2,
      _expected: LimitOrderTester.LimitOrderAssertData({
        account: address(0),
        tpToken: address(0),
        triggerAboveThreshold: false,
        reduceOnly: false,
        sizeDelta: 0,
        subAccountId: 0,
        marketIndex: 0,
        triggerPrice: 0,
        acceptablePrice: 0,
        executionFee: 0
      })
    });
  }

  receive() external payable {}
}
