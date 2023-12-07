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
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
      block.timestamp + 5 minutes // minPublishTime
    );
    executeIntentInputs.cmds[1] = intentBuilder.buildTradeOrder(
      wbtcMarketIndex, // marketIndex
      -100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      18000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
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
      block.timestamp + 5 minutes // minPublishTime
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

  function testRevert_TC43_intentHandler_replayIntent() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
      block.timestamp + 5 minutes // minPublishTime
    );
    executeIntentInputs.cmds[1] = intentBuilder.buildTradeOrder(
      wbtcMarketIndex, // marketIndex
      -100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      18000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
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
  }

  function testCorrectness_TC43_intentHandler_executeMarketOrderFail() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
      0, // acceptablePrice as 0 to make this order fail
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
    );
    executeIntentInputs.cmds[1] = intentBuilder.buildTradeOrder(
      wbtcMarketIndex, // marketIndex
      -100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      18000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
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

    intentHandler.execute(executeIntentInputs);

    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 1);

    // Initial collateral = 100,000 usdc
    // 1st trade's trading fee = 100000 - 100 = 99900
    // 1st trade's execution fee = 99900 - 0.1 = 99899.9
    // 2nd trade's execution fee = 99899.9 - 0.1 = 99899.8
    assertEq(vaultStorage.traderBalances(BOB, address(usdc)), 99899.8 * 1e6);
  }

  function testCorrectness_TC43_intentHandler_payExecutionFeeWithMultipleToken() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
    dai.mint(BOB, 0.1 * 1e18);
    depositCollateral(BOB, 0, ERC20(address(dai)), 0.1 * 1e18);
    wbtc.mint(BOB, 100 * 1e8);
    depositCollateral(BOB, 0, ERC20(address(wbtc)), 1 * 1e8);
    {
      assertVaultTokenBalance(address(dai), 0.1 * 1e18, "TC43: after deposit collateral");
      assertVaultTokenBalance(address(wbtc), 101 * 1e8, "TC43: after deposit collateral");
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
    executeIntentInputs.accountAndSubAccountIds = new bytes32[](1);
    executeIntentInputs.accountAndSubAccountIds[0] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);

    executeIntentInputs.cmds = new bytes32[](1);
    executeIntentInputs.cmds[0] = intentBuilder.buildTradeOrder(
      wethMarketIndex, // marketIndex
      100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      4000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, executeIntentInputs.cmds[0]);
    executeIntentInputs.signatures = new bytes[](1);
    executeIntentInputs.signatures[0] = abi.encodePacked(r, s, v);

    executeIntentInputs.priceData = pyth.buildPriceUpdateData(tickPrices);
    executeIntentInputs.publishTimeData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    executeIntentInputs.minPublishTime = block.timestamp;
    executeIntentInputs.encodedVaas = keccak256("someEncodedVaas");

    intentHandler.execute(executeIntentInputs);

    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 1);

    // Initial collateral = 0.1 DAI
    //                    = 1 WBTC (WBTC @ $19,998.3457779) = $19,998.3457779
    // 1st trade's execution fee = 0.1 DAI - 0.1 = 0 DAI
    // 1st trade's trading fee = 19998.3457779 - 100 = 19898.3457779 => 19898.3457779/19,998.3457779 = 0.99499959 WBTC

    assertEq(vaultStorage.traderBalances(BOB, address(dai)), 0 * 1e18);
    assertEq(vaultStorage.traderBalances(BOB, address(wbtc)), 0.99499959 * 1e8);
  }

  function testRevert_TC43_intentHandler_badSignature() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);
    uint256 anotherPivateKey = uint256(keccak256(bytes("2")));

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
    dai.mint(BOB, 0.1 * 1e18);
    depositCollateral(BOB, 0, ERC20(address(dai)), 0.1 * 1e18);
    wbtc.mint(BOB, 100 * 1e8);
    depositCollateral(BOB, 0, ERC20(address(wbtc)), 1 * 1e8);
    // Long ETH
    vm.deal(BOB, 1 ether);

    {
      // before create order, must be empty
      assertEq(limitTradeHandler.limitOrdersIndex(getSubAccount(BOB, 0)), 0);
      assertEq(BOB.balance, 1 ether);
    }

    // Bob will open two positions on ETH and BTC markets
    IIntentHandler.ExecuteIntentInputs memory executeIntentInputs;
    executeIntentInputs.accountAndSubAccountIds = new bytes32[](1);
    executeIntentInputs.accountAndSubAccountIds[0] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);

    executeIntentInputs.cmds = new bytes32[](1);
    executeIntentInputs.cmds[0] = intentBuilder.buildTradeOrder(
      wethMarketIndex, // marketIndex
      100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      4000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(anotherPivateKey, executeIntentInputs.cmds[0]); // sign the message with other private key that is not BOB
    executeIntentInputs.signatures = new bytes[](1);
    executeIntentInputs.signatures[0] = abi.encodePacked(r, s, v); // supply wrong sinature here

    executeIntentInputs.priceData = pyth.buildPriceUpdateData(tickPrices);
    executeIntentInputs.publishTimeData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    executeIntentInputs.minPublishTime = block.timestamp;
    executeIntentInputs.encodedVaas = keccak256("someEncodedVaas");

    vm.expectRevert(abi.encodeWithSignature("IntenHandler_BadSignature()"));
    intentHandler.execute(executeIntentInputs);

    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 0);

    // No execution fee should be collected
    assertEq(vaultStorage.traderBalances(BOB, address(dai)), 0.1 * 1e18);
    assertEq(vaultStorage.traderBalances(BOB, address(wbtc)), 100 * 1e8);
  }

  function testCorrectness_TC43_intentHandler_notEnoughCollateralForExecutionFee() external {
    uint256 privateKey = uint256(keccak256(bytes("1")));
    BOB = vm.addr(privateKey);

    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;
    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig, false);

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
    dai.mint(BOB, 1205 * 1e18);
    depositCollateral(BOB, 0, ERC20(address(dai)), 1205 * 1e18);

    // Long ETH
    vm.deal(BOB, 1 ether);

    {
      // before create order, must be empty
      assertEq(limitTradeHandler.limitOrdersIndex(getSubAccount(BOB, 0)), 0);
      assertEq(BOB.balance, 1 ether);
    }

    // Bob will open two positions on ETH and BTC markets
    IIntentHandler.ExecuteIntentInputs memory executeIntentInputs;
    executeIntentInputs.accountAndSubAccountIds = new bytes32[](1);
    executeIntentInputs.accountAndSubAccountIds[0] = intentBuilder.buildAccountAndSubAccountId(BOB, 0);

    executeIntentInputs.cmds = new bytes32[](1);
    executeIntentInputs.cmds[0] = intentBuilder.buildTradeOrder(
      wethMarketIndex, // marketIndex
      100_000 * 1e30, // sizeDelta
      0, // triggerPrice
      4000 * 1e30, // acceptablePrice
      true, // triggerAboveThreshold
      false, // reduceOnly
      address(usdc), // tpToken
      block.timestamp + 5 minutes // minPublishTime
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, executeIntentInputs.cmds[0]);
    executeIntentInputs.signatures = new bytes[](1);
    executeIntentInputs.signatures[0] = abi.encodePacked(r, s, v);

    executeIntentInputs.priceData = pyth.buildPriceUpdateData(tickPrices);
    executeIntentInputs.publishTimeData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    executeIntentInputs.minPublishTime = block.timestamp;
    executeIntentInputs.encodedVaas = keccak256("someEncodedVaas");

    intentHandler.execute(executeIntentInputs);

    // The order failed to executed here because collateral is short by 0.1 usd for the exection fee.
    // Therefore, no position will be opened.
    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 0);

    // Initial collateral = 1205 DAI
    // 1st trade's execution fee = 1205 - 0.1 = 1204.9 DAI
    // execution fee is deducted even if the order failed
    assertEq(vaultStorage.traderBalances(BOB, address(dai)), 1204.9 * 1e18);
  }
}
