// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";
import "forge-std/console.sol";

contract TC05 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC05() external {
    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);
      /*
       Alice balance
       +-------+---------+
       | Token | Balance |
       +-------+---------+
       | USDT  | 100,000 |
       | WBTC  | 0.5     |
       +-------+---------+
       */
      usdt.mint(ALICE, 100_000 * 1e6);
      wbtc.mint(ALICE, 0.5 * 1e8);

      /*
       Alice balance
       +-------+---------+
       | Token | Balance |
       +-------+---------+
       | WBTC  | 10      |
       +-------+---------+
       */
      wbtc.mint(BOB, 10 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
    {
      updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125
      // buy
      getPositionId(ALICE, 0, jpyMarketIndex);
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.007945967421533571712355979340 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (200 * MINUTES));
    {
      updatePriceData = new bytes[](3);
      // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 125.85 * 1e3, 0);
      // updatePriceData[1] = _createPriceFeedUpdateData(usdcAssetId, 1 * 1e8, 0);
      // updatePriceData[2] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);
      tickPrices[1] = 99039;
      tickPrices[2] = 0;
      tickPrices[6] = 48353;

      uint256 protocolFeesBefore = vaultStorage.protocolFees(address(wbtc));
      uint256 devFeesBefore = vaultStorage.devFees(address(wbtc));

      liquidate(getSubAccount(ALICE, 0), tickPrices, publishTimeDiff, block.timestamp);
      /*
       *
       * |       loss        | trading |      borrowing     |     funding    | liquidation | unit |
       * |-------------------|---------|--------------------|----------------|-------------|------|
       * | 675.4072308303536 |      30 | 1.4623871614844526 | 15.99999999996 |           5 |  USD |
       * |        0.03377036 |  0.0015 |         0.00007311 |     0.00079999 |     0.00025 |  BTC |
       * |                      0.0015                                                            |

       * total pay: 0.03377036 + 0.0015 + 0.00007311 + 0.00079999 + 0.00025 = 0.03639346
       * trader balance = 0.04850000 - 0.03639346 = 0.01210654
       * dev fee = (0.0015 * 10%) + (0.00007311 * 10%) + (0.0015 * 10%)
       * hlp liquidity = 9.97 + (0.03377036 + (0.00007311 - 0.00001096)) = 10.00383251
       * protocol fee = 0.0015 - (0.0015 * 10%) = 0.00135
       * liquidation fee = 0.00025
       */
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 1213266);
      console.log("dev fee:", devFeesBefore);
      assertVaultsFees(address(wbtc), protocolFeesBefore + (0.00135 * 1e8), 7313 + 15001 + 300000 + 15001, 0); // calculate 2 times for tradingFee
      assertHLPLiquidity(address(wbtc), 10.00383251 * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00025 * 1e8);
      assertNumberOfPosition(ALICE, 0);
      assertPositionInfoOf(ALICE, jpyMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(jpyMarketIndex, 0, 0);
    }
  }
}
