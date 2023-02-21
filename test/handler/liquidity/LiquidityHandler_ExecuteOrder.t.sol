// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LiquidityHandler_Base, IConfigStorage, IPerpStorage } from "./LiquidityHandler_Base.t.sol";
import { ILiquidityHandler } from "../../../src/handlers/interfaces/ILiquidityHandler.sol";

contract LiquidityHandler_ExecuteOrder is LiquidityHandler_Base {
  function setUp() public override {
    super.setUp();

    liquidityHandler.setOrderExecutor(address(this), true);
  }

  function test_correctness_executeOrder_IncreaseOneOrder() external {
    ILiquidityHandler.LiquidityOrder memory increaseOrder = ILiquidityHandler.LiquidityOrder({
      account: payable(ALICE),
      token: address(wbtc),
      amount: 1 ether,
      minOut: 1 ether,
      isAdd: true,
      status: ILiquidityHandler.LiquidityOrderStatus.PROCESSING
    });

    ILiquidityHandler.LiquidityOrder[] memory orders;
    orders[0] = increaseOrder;

    liquidityHandler.executeOrders(orders, new bytes[](0));
  }
}
