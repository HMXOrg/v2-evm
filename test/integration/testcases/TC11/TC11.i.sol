// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { console2 } from "forge-std/console2.sol";

contract TC11 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // TC11 - not allow trader to do trade when market has been delisted
  function testCorrectness_TC11_TradeWithDelistedMarket() external {
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

    // Given Bob provide 1 btc as liquidity
    // And Btc price is 20,000 USD
    // And WETH price is 1,500 USD
    updatePriceData = new bytes[](2);
    updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1500 * 1e8, 0);
    updatePriceData[1] = _createPriceFeedUpdateData(wbtcAssetId, 20000 * 1e8, 0);
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, updatePriceData, true);

    // When Alice deposit collateral 0.1 btc for sub-account 0
    depositCollateral(ALICE, 0, wbtc, 0.1 * 1e8);
    // And Bob deposit collateral 0.2 btc for sub-account 0
    depositCollateral(BOB, 0, wbtc, 0.2 * 1e8);
    // Then Alice's sub-account 0 should has 0.1 btc
    assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.1 * 1e8);
    // Then Bob's sub-account 0 should has 0.2 btc
    assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.2 * 1e8);

    // ### Scenario: Traders trade normally
    // Given Alice buy position at WETH for 3000 USD
    marketBuy(ALICE, 0, wethMarketIndex, 3_000 * 1e30, address(0), updatePriceData);
    // And Alice sell position at APPLE for 3000 USD
    marketSell(ALICE, 0, appleMarketIndex, 3_000 * 1e30, address(0), updatePriceData);
    // And Bob buy position at APPLE for 3000 USD
    marketBuy(BOB, 0, appleMarketIndex, 3_000 * 1e30, address(0), updatePriceData);

    // When Bot try force close Bob's APPLE position
    // Then Revert MarketHealthy
    vm.expectRevert(abi.encodeWithSignature("ITradeService_MarketHealthy()"));
    closeDelistedMarketPosition(ALICE, 0, appleMarketIndex, address(wbtc), updatePriceData);

    // ### Scenario: Delist market & Traders try to manage position
    // When APPLE's market has been delist
    toggleMarket(appleMarketIndex);

    // And Alice sell more APPLE position for 3000 USD
    // Then Revert MarketDelisted
    marketSell(
      ALICE,
      0,
      appleMarketIndex,
      3_000 * 1e30,
      address(0),
      updatePriceData,
      "ITradeService_MarketIsDelisted()"
    );

    // And Alice try to fully close APPLE position
    // Then Still Revert MarketDelisted
    marketBuy(
      ALICE,
      0,
      appleMarketIndex,
      3_000 * 1e30,
      address(0),
      updatePriceData,
      "ITradeService_MarketIsDelisted()"
    );

    // When Alice try increase WETH position for 3000 USD
    marketBuy(ALICE, 0, wethMarketIndex, 3_000 * 1e30, address(0), updatePriceData);
    {
      // Then Alice has corrected positions
      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: int256(6_000 * 1e30),
        _avgPrice: 1_500.015 * 1e30,
        _reserveValue: 540 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: appleMarketIndex,
        _positionSize: -int256(3_000 * 1e30),
        _avgPrice: 151.99924 * 1e30,
        _reserveValue: 1_350 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
      // And Bob should has corrected position
      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: appleMarketIndex,
        _positionSize: int256(3_000 * 1e30),
        _avgPrice: 151.99924 * 1e30,
        _reserveValue: 1_350 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
    }

    // ### Scenario: Bot close all traders position in delisted market
    // When Bot close all position under APPLE's market
    closeDelistedMarketPosition(ALICE, 0, appleMarketIndex, address(wbtc), updatePriceData);
    closeDelistedMarketPosition(BOB, 0, appleMarketIndex, address(wbtc), updatePriceData);
    {
      // Then all positions should be closed
      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: appleMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: appleMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
    }

    // ### Scenario: Traders try to trade on delist market again
    // When Bob try buy APPLE's market again
    // Then Revert MarketDelisted
    marketBuy(BOB, 0, appleMarketIndex, 3_000 * 1e30, address(0), updatePriceData, "ITradeService_MarketIsDelisted()");

    // ### Scenario: List new market and Trader could trade
    // When re-list APPLE's market with new ID

    // IMF = 5%, Max leverage = 20
    // MMF = 2.5%
    // Increase / Decrease position fee = 0.05%
    uint256 _newAppleMarketIndex = addMarketConfig(appleAssetId, 1, 500, 250, 5);
    // And Bob try buy APPLE's market 3,000 USD again
    marketBuy(BOB, 0, _newAppleMarketIndex, 3_000 * 1e30, address(0), updatePriceData);
    {
      // Then Bob APPLE's position shoule be corrected
      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: _newAppleMarketIndex,
        _positionSize: int256(3000 * 1e30),
        _avgPrice: 152.00076 * 1e30,
        _reserveValue: 1350 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });

      // should not affected old market
      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: appleMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0
      });
    }

    // And old APPLE's market should not has any position
    assertMarketLongPosition({ _marketIndex: appleMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "APPLE (old): " });
    assertMarketShortPosition({
      _marketIndex: appleMarketIndex,
      _positionSize: 0,
      _avgPrice: 0,
      _str: "APPLE (old): "
    });

    // And new APPLE's market state should corrected
    assertMarketLongPosition({
      _marketIndex: _newAppleMarketIndex,
      _positionSize: 3000 * 1e30,
      _avgPrice: 152.00076 * 1e30,
      _str: "APPLE (new): "
    });
    assertMarketShortPosition({
      _marketIndex: _newAppleMarketIndex,
      _positionSize: 0,
      _avgPrice: 0,
      _str: "APPLE (new): "
    });

    // And WETH's market should be corrected
    assertMarketLongPosition({
      _marketIndex: wethMarketIndex,
      _positionSize: 6000 * 1e30,
      _avgPrice: 1500.014999962500374996250037499625 * 1e30,
      _str: "WETH: "
    });
    assertMarketShortPosition({ _marketIndex: wethMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "WETH:  " });
  }
}
