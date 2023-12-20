// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console2 } from "forge-std/console2.sol";

contract TC20 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // TC20 - Trade with max utilization
  function testCorrectness_TC20_TradeWithMaxUtilization() external {
    // ### Scenario: Prepare environment

    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);
    vm.deal(FEEVER, 1 ether);
    // @todo - fix function in bot handler to be payable
    vm.deal(address(botHandler), 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // warp to block timestamp 1000
    vm.warp(1000);

    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    address _bobSubAccount0 = getSubAccount(BOB, 0);

    // ### Scenario: Prepare environment
    // Given Max Utilization is 80%
    // And BTC price is 20,000 USD
    // And WETH price is 1,500 USD
    // And APPLE price is 152 USD
    updatePriceData = new bytes[](3);
    tickPrices[0] = 73135; // ETH tick price $1,499.87
    tickPrices[1] = 99039; // WBTC tick price $20,000
    tickPrices[6] = 50241; // JPY tick price $152

    // And Bob provide liquidity 5 btc
    addLiquidity(BOB, wbtc, 5 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    {
      // HLP liquidity and total supply should be corrected
      // 5 * 0.997 = 4.985
      // 4.985 * 20000 = 99700
      assertHLPLiquidity(address(wbtc), 4.985 * 1e8);
      assertHLPTotalSupply(99700 * 1e18);
      assertTVL(99700 * 1e30, false);
    }

    // And Alice deposit 5 btc as Collateral
    depositCollateral(ALICE, 0, wbtc, 5 * 1e8);

    // And Bob deposit 0.5 btc as Collateral
    depositCollateral(BOB, 0, wbtc, 0.5 * 1e8);
    {
      // check balances
      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 5 * 1e8);
      assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.5 * 1e8);
    }

    // ### Scenario: Traders buy / sell
    // When Alice sell WETH 600,000 USD
    marketSell(ALICE, 0, wethMarketIndex, 600_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    {
      // avg price = 1500 * (1 + ((0 - 600000) / 300000000 / 2)) = 1498.5
      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: -int256(600_000 * 1e30),
        _avgPrice: 1498.5 * 1e30,
        _reserveValue: 54_000 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0
      });

      // 600000 * 1% (IMF) = 6000 * 900% (max profit) = 54,000
      // Then Alice's WETH position should be corrected
      assertAssetClassReserve(0, 54_000 * 1e30);
      assertGlobalReserve(54_000 * 1e30);
    }

    // ETH Price moved down which will cause Bob's ETH Short Position to be profitable
    tickPrices[0] = 70904; // ETH tick price $1,199.96
    tickPrices[1] = 99039; // WBTC tick price $20,000
    tickPrices[6] = 50241; // JPY tick price $152

    // When Bob buy APPLE 20,000 USD. It will fail with insufficient liquidity error.
    marketBuy(BOB, 0, appleMarketIndex, 20_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);

    // The profit from Bob's Short ETH position is
    // (1498.5 - 1199.96) / 1498.5 * 600000 =~ 119535.53553554 USD
    // (Value is negative here because it is a loss for HLP.)
    assertApproxEqRel(calculator.getGlobalPNLE30(), -119973.740610399324970329821688817484 * 1e30, MAX_DIFF);

    // HLP TVL is only 99,700 USD. At this point the platform can't handle anymore position.

    // Assert that Bob's APPL position will not be opened.
    assertPositionInfoOf({
      _subAccount: _bobSubAccount0,
      _marketIndex: appleMarketIndex,
      _positionSize: 0,
      _avgPrice: 0,
      _reserveValue: 0,
      _realizedPnl: 0,
      _entryBorrowingRate: 0,
      _lastFundingAccrued: 0
    });

    // ETH Price moved up a bit to 1,400 USD
    // Bob's Short ETH position would still be profitable. But it should leave some room for new positions.
    tickPrices[0] = 72445; // ETH tick price $1,399.87
    tickPrices[1] = 99039; // WBTC tick price $20,000
    tickPrices[6] = 50241; // JPY tick price $152

    // Bob open Long APPLE position with the size of 20,000 USD.
    marketBuy(BOB, 0, appleMarketIndex, 20_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);

    // The profit from Bob's Short ETH position is
    // (1498.5 - 1399.87) / 1498.5 * 600000 =~ 39491.49149149 USD
    // (Value is negative here because it is a loss for HLP.)
    assertApproxEqRel(calculator.getGlobalPNLE30(), -40002.060093771468335757084769515095 * 1e30, MAX_DIFF);
  }
}
