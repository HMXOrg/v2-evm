// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";


contract TC41 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;
  uint8 subAccountId = 0;

  function testCorrectness_TC41_BatchCancelLimitTradeOrder() external {

    address _tokenAddress = address(weth);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 10_000_000 * 1e6);

      // Mint collateral and gas for ALICE
      vm.deal(ALICE, 20 ether);
    }

    // BOB add liquidity
    addLiquidity(BOB, usdc, 10_000_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // Deposit Collateral   
    depositCollateral(ALICE, subAccountId, ERC20(_tokenAddress), 10 ether, true);

    address _aliceSubAccount0 = getSubAccount(ALICE, subAccountId);

    // Create Limit Orders
    {
      createLimitTradeOrder({
        _account: ALICE, 
        _subAccountId: subAccountId, 
        _marketIndex: wethMarketIndex, 
        _sizeDelta: 1_000 * 1e30, 
        _triggerPrice: 0, 
        _acceptablePrice: type(uint256).max, 
        _triggerAboveThreshold: true, 
        _executionFee: 0.0001 ether, 
        _reduceOnly: false, 
        _tpToken: _tokenAddress
        }); 
      createLimitTradeOrder({
        _account: ALICE, 
        _subAccountId: subAccountId, 
        _marketIndex: wbtcMarketIndex, 
        _sizeDelta: 1_000 * 1e30, 
        _triggerPrice: 0, 
        _acceptablePrice: type(uint256).max, 
        _triggerAboveThreshold: true, 
        _executionFee: 0.0001 ether, 
        _reduceOnly: false, 
        _tpToken: _tokenAddress
        }); 
      createLimitTradeOrder({
        _account: ALICE, 
        _subAccountId: subAccountId, 
        _marketIndex: jpyMarketIndex, 
        _sizeDelta: 1_000 * 1e30, 
        _triggerPrice: 0, 
        _acceptablePrice: type(uint256).max, 
        _triggerAboveThreshold: true, 
        _executionFee: 0.0001 ether, 
        _reduceOnly: false, 
        _tpToken: _tokenAddress
        }); 
    }

    // Check orders length after create
    // Must equal to 3
    {
      vm.prank(ALICE);
      assertEq(limitTradeHandler.getAllActiveOrdersBySubAccount(_aliceSubAccount0, 5, 0).length, 3);
    }

    // Batch Cancel Order
    {
      vm.startPrank(ALICE);
      // Get all limit order
      ILimitTradeHandler.LimitOrder[] memory _orders = limitTradeHandler.getAllActiveOrdersBySubAccount(_aliceSubAccount0, 5, 0);
      uint256[] memory _orderIndexes = new uint256[](_orders.length);
      // Populate _orderIndexes with order get
      for (uint256 i = 0; i < _orders.length; ++i) {
        _orderIndexes[i] = _orders[i].orderIndex;
      }
      limitTradeHandler.batchCancelOrder(ALICE, subAccountId, _orderIndexes);
      vm.stopPrank();
    }

    // Check orders length after cancel
    // Must equal to 0
    {
      vm.prank(ALICE);
      assertEq(limitTradeHandler.getAllActiveOrdersBySubAccount(_aliceSubAccount0, 5, 0).length, 0);
    }
  }
}