// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IIntentHandler } from "@hmx/handlers/interfaces/IIntentHandler.sol";

contract TC43 is BaseIntTest_WithActions {
  function testCorrectness_TC43_intentHandler_executeMarketOrderSuccess() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig);

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(
      ALICE,
      ERC20(address(wbtc)),
      100 * 1e8,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    // T2: Create market order
    {
      assertVaultTokenBalance(address(usdc), 0, "TC43: before deposit collateral");
    }
    usdc.mint(BOB, 100_000 * 1e6);
    depositCollateral(BOB, 0, ERC20(address(usdc)), 100_000 * 1e6);
    {
      assertVaultTokenBalance(address(usdc), 100_000 * 1e6, "TC43: after deposit collateral");
    }

    // Long ETH
    vm.deal(BOB, 1 ether);

    {
      // before create order, must be empty
      assertEq(limitTradeHandler.limitOrdersIndex(getSubAccount(BOB, 0)), 0);
      assertEq(BOB.balance, 1 ether);
    }

    // Bob will open two positions on ETH and BTC markets
    IIntentHandler.ExecuteIntentInputs memory executeIntentInputs;
    executeIntentInputs.accountAndSubAccountIds = new bytes32[](2);
    executeIntentInputs.accountAndSubAccountIds[0] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);
    executeIntentInputs.accountAndSubAccountIds[1] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);

    executeIntentInputs.cmds = new bytes32[](2);
    executeIntentInputs.cmds[0] = intentBuilder.buildTradeOrder(
      wethMarketIndex, // marketIndex
      100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      4000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp // minPublishTime
    );
    executeIntentInputs.cmds[1] = intentBuilder.buildTradeOrder(
      wbtcMarketIndex, // marketIndex
      -100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      18000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp // minPublishTime
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, executeIntentInputs.cmds[0]);
    executeIntentInputs.signatures = new bytes[](2);
    executeIntentInputs.signatures[0] = abi.encodePacked(r, s, v);

    (v, r, s) = vm.sign(privateKey, executeIntentInputs.cmds[1]);
    executeIntentInputs.signatures[1] = abi.encodePacked(r, s, v);

    executeIntentInputs.priceData = pyth.buildPriceUpdateData(tickPrices);
    executeIntentInputs.publishTimeData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    executeIntentInputs.minPublishTime = block.timestamp;
    executeIntentInputs.encodedVaas = keccak256("someEncodedVaas");

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("IntentHandler_Unauthorized()"));
    intentHandler.execute(executeIntentInputs);
    vm.stopPrank();

    intentHandler.execute(executeIntentInputs);

    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 2);

    // Initial collateral = 100,000 usdc
    // 1st trade's trading fee = 100000 - 100 = 99900
    // 1st trade's execution fee = 99900 - 0.1 = 99899.9
    // 2nd trade's trading fee = 99899.9 - 100 = 99799.9
    // 2nd trade's execution fee = 99799.9 - 0.1 = 99799.8
    assertEq(vaultStorage.traderBalances(BOB, address(usdc)), 99799.8 * 1e6);

    // Test intent replay, should revert
    vm.expectRevert(abi.encodeWithSignature("IntentHandler_IntentReplay()"));
    intentHandler.execute(executeIntentInputs);

    vm.warp(block.timestamp + 5 minutes);

    // Test order stale
    // Bob will create an order, but the order took too long to be executed
    executeIntentInputs.accountAndSubAccountIds = new bytes32[](1);
    executeIntentInputs.accountAndSubAccountIds[0] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);

    executeIntentInputs.cmds = new bytes32[](1);
    executeIntentInputs.cmds[0] = intentBuilder.buildTradeOrder(
      appleMarketIndex, // marketIndex
      10_000 * 1e30, // sizeDelta
      0, // triggerPrice
      4000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp // minPublishTime
    );

    (v, r, s) = vm.sign(privateKey, executeIntentInputs.cmds[0]);
    executeIntentInputs.signatures[0] = abi.encodePacked(r, s, v);

    executeIntentInputs.priceData = pyth.buildPriceUpdateData(tickPrices);
    executeIntentInputs.publishTimeData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    executeIntentInputs.minPublishTime = block.timestamp;
    executeIntentInputs.encodedVaas = keccak256("someEncodedVaas");

    vm.warp(block.timestamp + 10 minutes);

    intentHandler.execute(executeIntentInputs);

    // New position should not be opened, as the order should be stale
    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 2);
  }
}
