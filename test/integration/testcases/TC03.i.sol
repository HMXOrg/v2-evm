// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

contract TC03 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // TC03 - trader could loss both long and short position
  function testCorrectness_TC03_TradeWithLossScenario() external {
    // prepare token for wallet

    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);
    vm.deal(FEEVER, 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // warp to block timestamp 1000
    vm.warp(1000);

    // T1: BOB provide liquidity as WBTC 1 token
    // note: price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    {
      // When Bob provide 1 BTC as liquidity
      assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8, "T1: ");

      // Then Bob should pay fee for 0.3% = 0.003 BTC

      // Assert HLP Liquidity
      //    BTC = 0.997 (amount - fee)
      assertHLPLiquidity(address(wbtc), 0.997 * 1e8, "T1: ");

      // When HLP Token price is 1$
      // Then HLP Token should Mint = 0.997 btc * 20,000 USD = 19,940 USD
      //                            = 19940 / 1 = 19940 Tokens
      assertHLPTotalSupply(19_940 * 1e18, "T1: ");

      // Assert Fee distribution
      // According from T0
      // Vault's fees has nothing

      // Then after Bob provide liquidity, then Bob pay fees
      //    Add Liquidity fee
      //      BTC - 0.003 btc
      //          - distribute all  protocol fee

      // In Summarize Vault's fees
      //    BTC - protocol fee  = 0 + 0.003 = 0.00309563 btc

      assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _devFee: 0, _fundingFeeReserve: 0, _str: "T1: " });

      // Finally after Bob add liquidity Vault balance should be correct
      // note: token balance is including all liquidity, dev fee and protocol fee
      //    BTC - 1
      assertVaultTokenBalance(address(wbtc), 1 * 1e8, "T1: ");
    }

    // time passed for 60 seconds
    skip(60);

    // T2: alice deposit BTC 200 USD at price 20,000
    // 200 / 20000 = 0.01 BTC
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    depositCollateral(ALICE, 0, wbtc, 0.01 * 1e8);
    {
      // When Alice deposit Collateral for 0.01 btc
      assertTokenBalanceOf(ALICE, address(wbtc), 99.99 * 1e8, "T2: ");

      // Then Vault btc's balance should be increased by 0.01
      assertVaultTokenBalance(address(wbtc), 1.01 * 1e8, "T2: ");

      // And Alice's sub-account balances should be correct
      //    BTC - 0.01
      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01 * 1e8, "T2: ");

      // And HLP total supply and Liquidity must not be changed
      // note: data from T1
      assertHLPTotalSupply(19_940 * 1e18, "T2: ");
      assertHLPLiquidity(address(wbtc), 0.997 * 1e8, "T2: ");

      // And Alice should not pay any fee
      // note: vault's fees should be same with T1
      assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _devFee: 0, _fundingFeeReserve: 0, _str: "T2: " });
    }

    // time passed for 60 seconds
    skip(60);

    // T3: ALICE market buy weth with 200,000 USD (1000x) at price 20,000 USD
    // should revert InsufficientFreeCollateral
    // note: price has no changed
    marketBuy(
      ALICE,
      0,
      wethMarketIndex,
      100_000 * 1e30,
      address(0),
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      "ITradeService_InsufficientFreeCollateral()"
    );

    // T4: ALICE market buy weth with 300 USD at price 20,000 USD
    //     Then Alice should has Long Position in WETH market
    // initialPriceFeedDatas is from
    marketBuy(ALICE, 0, wethMarketIndex, 300 * 1e30, address(0), tickPrices, publishTimeDiff, block.timestamp);
    {
      // When Alice Buy WETH Market
      // And Alice has no position
      // Then it means Alice open new Long position
      // Given increase size = 300 USD
      // WETH Price = 1500 USD

      // Then Check position Info
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 0
      // new Market skew      = 0 + 300
      // Premium before       = 0 / 300000000 = 0
      // Premium after        = 300 / 300000000 = 0.000001
      // Premium median       = (0 + 0.000001) / 2 = 0.0000005
      // Adaptive price       = 1500 * (1 + 0.0000005)
      //                      = 1500.00075

      // WETH market IMF      = 1%
      // WETH market MMF      = 0.5%
      // Inc / Dec Fee        = 0.1%
      // Position size        = 300 USD
      // Avg price            = 1500.00075 USD
      // IMR                  = 300 * IMF = 3 USD
      // MMR                  = 300 * MMF = 1.5 USD
      // Reserve              = IMR * Max profit
      //                      = 3 * 900%
      //                      = 27
      // Trading fee          = 300 * 0.1% = 0.3 USD

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: int256(300 * 1e30),
        _avgPrice: 1_500.00075 * 1e30, // 1,500.00075
        _reserveValue: 27 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0,
        _str: "T4: "
      });

      // Sub-account's state
      // According from T2
      //    IMR           = 0 USD
      //    MMR           = 0 USD
      // In Summarize
      //    IMR = 0 + 3   =   3 USD
      //    MMR = 0 + 1.5 = 1.5 USD

      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 3 * 1e30, _mmr: 1.5 * 1e30, _str: "T4: " });

      // Assert Alice Sub-account's Collateral
      // According to T2, Alice's collateral balances
      //    BTC - 0.01
      // When Alice buy WETH with 300 USD
      // Then Alice has fees to pay below
      //    Trading fee - 0.3 USD

      // Then Alice pay fee by Collateral
      //    BTC, (price: 20,000 USD)
      //      Trading fee = 0.3 / 20000 = 0.000015 btc
      // In Summarize, Alice's collateral balances
      //    BTC - 0.01 - 0.000015 = 0.009985

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.009985 * 1e8, "T4: ");

      // Assert Fee distribution
      // According from T2
      // Vault's fees
      //    BTC - protocol fee  = 0.003 btc
      //        - dev fee       = 0 btc
      // and HLP's liquidity
      //    BTC - 0.997 btc

      // Alice paid fees list
      //    BTC
      //      Trading fee - 0.000015 btc
      //                  - pay for protocol (85%)  = 0.00001275 btc
      //                  - pay for dev (15%)       = 0.00000225 btc
      //    Borrowing fee = 0 USD
      //    Funding fee   = 0 USD

      // In Summarize Vault's fees
      //    BTC - protocol fee  = 0.003 + 0.00001275 = 0.00301275 btc
      //        - dev fee       = 0 + 0.00000225     = 0.00000225 btc
      // and HLP's liquidity still be
      //    BTC - 0.997 btc
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301275 * 1e8,
        _devFee: 0.00000225 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T4: "
      });

      assertHLPLiquidity(address(wbtc), 0.997 * 1e8, "T4: ");

      // Assert Market
      assertMarketLongPosition(wethMarketIndex, 300 * 1e30, 1_500.00075 * 1e30, "T4: ");
      assertMarketShortPosition(wethMarketIndex, 0, 0, "T4: ");
      assertMarketFundingRate(wethMarketIndex, 0, 1120, "T4: ");

      // Assert Asset class
      // Crypto's reserve should be increased by = 27 USD
      assertAssetClassReserve(0, 27 * 1e30, "T4: ");
      // borrowing rate still not calculated
      assertAssetClassSumBorrowingRate(0, 0, 1120, "T4: ");

      // Invariant testing
      assertAssetClassReserve(1, 0, "T4: ");
      assertAssetClassSumBorrowingRate(1, 0, 0, "T4: ");
      assertAssetClassReserve(2, 0, "T4: ");
      assertAssetClassSumBorrowingRate(2, 0, 0, "T4: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T5: Alice withdraw BTC 200 USD (200 / 20000 = 0.01 BTC)
    // should revert ICrossMarginService_InsufficientBalance
    // vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()"));
    withdrawCollateral(ALICE, 0, wbtc, 0.1 * 1e8, tickPrices, publishTimeDiff, block.timestamp, executionOrderFee);

    // T6: Alice partial close Long position at WETH market for 150 USD
    //     WETH price 1,425 USD, then Alice should loss ~5%
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1_425 * 1e8, 0);
    tickPrices[0] = 72622;
    marketSell(ALICE, 0, wethMarketIndex, 150 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    {
      // When Alice Sell WETH Market
      // And Alice has Long position
      // Then it means Alice decrease Long position
      // Given decrease size = 150 USD
      // WETH Price = 1425 USD

      // Then Check position Info

      // Time passed          = 60 seconds (60 intervals)
      // TVL                  = 19,940 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 300
      // new Market skew      = 300 + -(300) = 0
      // Premium before       = 300 / 300000000 = 0.000001
      // Premium after        = 0 / 300000000 = 0.0000000
      // Premium median       = (0.000001 + 0.0000000) / 2 = 0.00000005
      // Adaptive price       = 1425 * (1 + 0.0000005)
      //                      = 1425.0007125

      // Market's Funding rate
      // Funding rate         = -(Intervals * (Skew ratio * Max funding rate))
      //                      = -(60 * 300 / 300000000 * 0.0004)
      //                      = -0.000000024
      assertMarketFundingRate(wethMarketIndex, 277777, 1180, "T6: ");

      // Crypto Borrowing rate
      //    = reserve * interval * base rate / tvl
      //    = 27 * 60 * 0.01% / 19940
      //    = 0.000008124373119358
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T6: ");

      // WETH market IMF      = 1%
      // WETH market MMF      = 0.5%
      // Inc / Dec Fee        = 0.1%
      // Borrowing base Rate  = 0.01%

      // Before:
      //    Position size     = 300
      //    Reserve           = 27 USD
      //    Avg price         = 1500.00075 USD
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      // After:
      //    Position size     = 300 - 150 = 150
      //    Avg price         = 1500.000375 USD
      //    IMR               = 150 * IMF = 1.5 USD
      //    MMR               = 150 * MMF = 0.75 USD
      //    Reserve           = IMR * Max profit
      //                      = 1.5 * 900%
      //                      = 13.5
      //    Trading fee       = 150 * 0.1% = 0.15 USD
      //    Borrowing rate    = 0.000008124373119358
      //    Funding rate      = -0.000000024

      //    Borrowing fee     = (0.000008124373119358 - 0) * 13.5 (reserve)
      //                      = 0.000219358074222666
      //    Funding fee       = (-0.000000024 - 0) * 150 (position size)
      //                      = -0.0000036 USD

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // to realized PnL - pnl * (size delta / position size)
      // pnl             = 300 * (1425.0007125 - 1500.00075) / 1500.00075 = -15 USD
      // to realized PnL = -15 * (150 / 300) = -7.5 USD
      // Then unrealzlied PnL = -15 - -(7.5) = -7.5 USD

      // new average price = (new close price * remaining size) / (remaining size + unrealized pnl)
      // premium after decrease = 300 - 150 = 150 / 300000000 = 0.0000005
      // premium after close    = 300 - 300 = 0 / 300000000 = 0
      // premium                = (0.0000005 + 0) / 2 = 0.00000025
      // price with premium     = 1425 * (1 + 0.00000025) = 1425.00035625
      // new average price      = (1425.00035625 * 150) / (150 - 7.5)
      //                        = 1500.000375 USD

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: int256(150 * 1e30),
        _avgPrice: 1500.000375 * 1e30,
        _reserveValue: 13.5 * 1e30,
        _realizedPnl: -7.5 * 1e30,
        _entryBorrowingRate: 0.000008124373119358 * 1e18,
        _lastFundingAccrued: -96,
        _str: "T6: "
      });

      // Sub-account's state
      // According from T4
      //    IMR           =   3 USD
      //    MMR           = 1.5 USD
      // In Summarize
      //    IMR = 3 - 1.5     =  1.5 USD
      //    MMR = 1.5 + 0.75  = 0.75 USD

      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T6: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Alice's collateral before settle payment
      //    BTC - 0.009985

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00301275 btc
      //        - dev fee       = 0.00000225 btc
      //        - funding fee   = 0.00000000 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.997 btc

      // Settlement detail
      // Then Alice has to pay
      //    Trading fee - 0.15 USD
      //      BTC - 0.15 / 20000                              = 0.00000750 btc
      //          - pay for dev (15%)                         = 0.00000112 btc
      //          - pay for protocol (85%)                    = 0.00000750 - 0.00000112
      //                                                      = 0.00000638 btc
      //    Borrowing fee - 0.000219358074222666 USD
      //      BTC - 0.000219358074222666 / 20000              = 0.00000001 btc
      //          - pay for dev (15%)                         = 0.00000000 btc
      //          - pay for HLP (85%)                         = 0.00000001 - 0.00000000
      //                                                      = 0.00000001 btc
      //    Funding fee - 0.0000036 USD
      //      BTC - 0.0000036 / 20000                         = 0.00000000 (018) btc
      //    Loss - 7.5 USD
      //      BTC - 7.5 / 20000  = 0.000375 btc
      //          - pay for HLP (100%)                        = 0.000375 btc

      // And HLP has to pay
      //    nothing

      // Alice's collateral after settle payment
      //    BTC = 0.009985 - 0.00000750 - 0.00000001 - 0.00000000 - 0.000375
      //        = 0.00960249 btc

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.00960249 * 1e8, "T6: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00301275 + 0.00000638              = 0.00301913 btc
      //        - dev fee       = 0.00000225 + 0.00000112 + 0.00000000 = 0.00000337 btc
      //        - funding fee   = 0.00000000 + 0.00000000              = 0.00000000 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301913 * 1e8,
        _devFee: 0.00000337 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T6: "
      });

      // HLP's liquidity after settle payment
      //    BTC = 0.997 + 0.00000001 + 0.000375
      //        = 0.99737501
      assertHLPLiquidity(address(wbtc), 0.99737501 * 1e8, "T6: ");

      // Assert Market

      // Average Price Calculation
      //  Long:
      //    Market's Avg price = 1500.00075, Current price = 1425.0007125
      //                                     next close price = 1425.00035625
      //    Market's PnL  = (300 * (1425.0007125 - 1500.00075)) / 1500.00075
      //                  = -15
      //    Actual PnL    = Market's PnL - Realized PnL = -15 - -(7.5)
      //                  = -7.5
      //    Avg Price     = Current Price * New Position size / New Position size + Actual PnL
      //                  = (1425.00035625 * 150) / (150 + -(7.5))
      //                  = 1500.000375

      assertMarketLongPosition(wethMarketIndex, 150 * 1e30, 1500.000375 * 1e30, "T6: ");
      assertMarketShortPosition(wethMarketIndex, 0, 0, "T6: ");

      // Assert Asset class
      // According T4
      // Crypto's reserve is 27
      // When alice decreased position reserve should be reduced by = 13.5 USD
      // Then 27 - 13.5 = 13.5 USD
      // note: sum of borrowing rate is calculated on position info
      assertAssetClassReserve(0, 13.5 * 1e30, "T6: ");

      // Invariant testing
      assertAssetClassReserve(1, 0, "T6: ");
      assertAssetClassReserve(2, 0, "T6: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T7: Alice Sell JPY Market for 6000 USD with same Sub-account
    marketSell(ALICE, 0, jpyMarketIndex, 6_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    {
      // When Alice Sell JPY Market
      // And Alice has no position
      // Then it means Alice open new Long position
      // Given increase size = 6000 USD
      // JPY Price = 136.123 USDJPY (pyth price)
      //           = 0.007346297098947275625720855402 USD

      // Adaptive price
      //    Market skew       = 0
      //    new Market skew   = 0 + -6000 (short position)
      //    Premium before    = 0 / 300000000 = 0
      //    Premium after     = -6000 / 300000000 = -0.00002
      //    Premium median    = (0 + -0.00002) / 2 = -0.00001
      //    Adaptive price    = 0.007346297098947275625720855402 * (1 + -0.00001)
      //                      = 0.007346223635976286152964598193

      // JPY market IMF       = 0.1%
      // JPY market MMF       = 0.05%
      // Inc / Dec Fee        = 0.03%
      // Position size        = 6000 USD
      // Avg price            = Adaptive price
      //                      = 0.007346223635976286152964598193
      // IMR                  = 6000 * IMF = 6 USD
      // MMR                  = 6000 * MMF = 3 USD
      // Reserve              = IMR * Max profit
      //                      = 6 * 900%
      //                      = 54
      // Trading fee          = 6000 * 0.03% = 1.8 USD

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: jpyMarketIndex,
        _positionSize: int256(-6_000 * 1e30),
        _avgPrice: 0.007346223635976286152964598193 * 1e30,
        _reserveValue: 54 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0,
        _str: "T7: "
      });

      // Sub-account's state
      // According from T6
      //    IMR             =  1.5 USD
      //    MMR             = 0.75 USD
      // In Summarize
      //    IMR = 1.5 + 6   =  7.5 USD
      //    MMR = 0.75 + 3  = 3.75 USD

      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 7.5 * 1e30, _mmr: 3.75 * 1e30, _str: "T7: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Alice's collateral before settle payment
      //    BTC - 0.00960249

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00301913 btc
      //        - dev fee       = 0.00000337 btc
      //        - funding fee   = 0.00000000 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99737501 btc

      // Settlement detail
      // Then Alice has to pay
      //    Trading fee - 1.8 USD
      //      BTC - 1.8 / 20000             = 0.00009000 btc
      //          - pay for dev (15%)       = 0.00001350 btc
      //          - pay for protocol (85%)  = 0.00009000 - 0.00001350
      //                                    = 0.0000765 btc

      // And HLP has to pay
      //    nothing

      // Alice's collateral after settle payment
      //    BTC = 0.00960249 - 0.00009000 = 0.00951249 btc

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.00951249 * 1e8, "T7: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00301913 + 0.00007650 = 0.00309563 btc
      //        - dev fee       = 0.00000337 + 0.00001350 = 0.00001687 btc
      //        - funding fee   = 0.00000000 + 0.00000000 = 0.00000000 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00309563 * 1e8,
        _devFee: 0.00001687 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T7: "
      });

      // HLP's liquidity after settle payment (nothing changed)
      //    BTC = 0.99737501 btc
      assertHLPLiquidity(address(wbtc), 0.99737501 * 1e8, "T7: ");

      // Assert Market
      assertMarketLongPosition(jpyMarketIndex, 0, 0, "T7: ");
      assertMarketShortPosition(jpyMarketIndex, 6_000 * 1e30, 0.007346223635976286152964598193 * 1e30, "T7: ");
      assertMarketFundingRate(jpyMarketIndex, 0, 1240, "T7: ");

      // Assert Asset class
      // Forex's reserve should be increased by = 54 USD
      assertAssetClassReserve(2, 54 * 1e30, "T7: ");
      assertAssetClassSumBorrowingRate(2, 0, 1240, "T7: ");

      // Invariant testing
      assertAssetClassReserve(0, 13.5 * 1e30, "T7: ");
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T7: ");

      assertAssetClassReserve(1, 0, "T7: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T8: Alice fully close JPY Short Position
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 135.714 * 1e3, 0);
    tickPrices[6] = 49107;
    marketBuy(ALICE, 0, jpyMarketIndex, 6_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    {
      // When Alice Buy JPY Market
      // And Alice has Short position
      // Then it means Alice decrease Short position
      // Given decrease size = 6000 USD (fully close)
      // And Price dump from T7 ~0.03%
      // JPY Price = 135.714 USDJPY (pyth price)
      //           = 0.007368436565129610799180629853 USD

      // And Time passed      = 60 seconds (60 intervals)
      // And TVL
      //  - BTC               = 0.99737501 * 20000 = 19947.5002
      //  - Total             = 19947.5002 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = -6000
      // new Market skew      = -6000 + 6000 (short position)
      // Premium before       = -6000 / 300000000 = -0.00002
      // Premium after        = 0 / 300000000 = 0
      // Premium median       = (-0.00002 + 0) / 2 = -0.00001
      // Adaptive price       = 0.007368436565129610799180629853 * (1 + -0.00001)
      //                      = 0.007368362880763959503072638046

      // Market's Funding rate
      // Funding rate         = -(Intervals * (Skew ratio * Max funding rate))
      //                      = -(60 * -6000 / 300000000 * 0.0004)
      //                      = 0.00000048
      assertMarketFundingRate(jpyMarketIndex, -5555555, 1300, "T8: ");

      // Forex Borrowing rate
      //    = reserve * interval * base rate / tvl
      //    = 54 * 60 * 0.03% / 19947.5002
      //    = 0.000048727910277198
      assertAssetClassSumBorrowingRate(2, 0.000048727910277198 * 1e18, 1300, "T8: ");

      // JPY market IMF       = 0.1%
      // JPY market MMF       = 0.05%
      // Inc / Dec Fee        = 0.03%

      // Before:
      //    Position size     = -6000
      //    Avg Price         = 0.007346223635976286152964598193 USD
      //    Reserve           = 54 USD
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      // After:
      //    Position size     = -6000 + 6000      = 0
      //    Avg price         = 0 USD (fully close)
      //    IMR               = 0
      //    MMR               = 0
      //    Reserve           = 0
      //    Borrowing rate    = 0
      //    Funding rate      = 0

      //    Trading fee       = 6000 * 0.03% = 1.8 USD

      //    Borrowing fee     = (0.000048727910277198 - 0) * 54 (reserve delta)
      //                      = 0.002631307154968692
      //    Funding fee       = (0.00000048 - 0) * 6000 (position size)
      //                      = 0.00288 USD

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 6000 * (0.007346223635976286152964598193 - 0.007368362880763959503072638046) / 0.007346223635976286152964598193
      //                = -18.082143330828064901189265355318 USD

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: jpyMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0,
        _str: "T8: "
      });

      // Sub-account's state
      // According from T7
      //    IMR             =  7.5 USD
      //    MMR             = 3.75 USD
      // In Summarize
      //    IMR = 7.5 - 6   =  1.5 USD
      //    MMR = 3.75 - 3  = 0.75 USD

      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T8: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Alice's collateral before settle payment
      //    BTC - 0.00951249

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00309563 btc
      //        - dev fee       = 0.00001687 btc
      //        - funding fee   = 0.00000000 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99737501 btc

      // Settlement detail
      // Then Alice has to pay
      //    Trading fee - 1.8 USD
      //      BTC - 1.8 / 20000                     = 0.00009000 btc
      //          - pay for dev (15%)               = 0.00001350 btc
      //          - pay for protocol (85%)          = 0.00009000 - 0.00001350
      //                                            = 0.0000765 btc
      //    Borrowing fee - 0.002631307154968692 USD
      //      BTC - 0.002631307154968692 / 20000    = 0.00000013 btc
      //          - pay for dev (15%)               = 0.00000001 btc
      //          - pay for HLP (85%)               = 0.00000013 - 0.00000001
      //                                            = 0.00000012 btc
      //    Funding fee - 0.00288 USD
      //      BTC - 0.00288 / 20000                 = 0.00000014 btc
      //          - pay for funding fee             = 0.00000014 btc
      //    Loss - 18.082143330828064901189265355318 USD
      //          - 18.082143330828064901189265355318 / 20000  = 0.00090410 btc
      //          - pay for HLP (100%)                         = 0.00090410 btc

      // And HLP has to pay
      //    nothing

      // Alice's collateral after settle payment
      //    BTC = 0.00951249 - 0.00009000 - 0.00000013 - 0.00000014 - 0.00090410
      //        = 0.00851812 btc

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.00849069 * 1e8, "T8: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00309563 + 0.00007650              = 0.00317213 btc
      //        - dev fee       = 0.00001687 + 0.00001350 + 0.00000001 = 0.00003038 btc
      //        - funding fee   = 0.00000000 + 0.00000014              = 0.00000014 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00317213 * 1e8,
        _devFee: 0.00003038 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T8: "
      });

      // HLP's liquidity after settle payment (nothing changed)
      //    BTC = 0.99737501 + 0.00000012 + 0.00090410
      //        = 0.99827923 btc
      assertHLPLiquidity(address(wbtc), 0.99827923 * 1e8, "T8: ");

      // Assert Market
      assertMarketLongPosition(jpyMarketIndex, 0, 0, "T8: ");
      assertMarketShortPosition(jpyMarketIndex, 0, 0, "T8: ");

      // Assert Asset class
      // Forex's reserve should be increased by = 54 USD
      assertAssetClassReserve(2, 0, "T8: ");

      // Invariant testing
      assertAssetClassReserve(0, 13.5 * 1e30, "T8: ");
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T8: ");

      assertAssetClassReserve(1, 0, "T8: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T9: Bob deposit BTC 100 USD at price 20,000
    // 100 / 20000 = 0.005 BTC
    address _bobSubAccount0 = getSubAccount(BOB, 0);
    depositCollateral(BOB, 0, wbtc, 0.01 * 1e8);

    assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.01 * 1e8, "T9: ");

    // BOB create limit order to open long position for 3000 USD at Btc price 18,000 USD
    // Order Index: 0
    createLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _marketIndex: wbtcMarketIndex,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 18_000 * 1e30,
      _acceptablePrice: 18450 * 1e30, // 18000 * (1 + 0.025) = 18450
      _triggerAboveThreshold: false,
      _executionFee: executionOrderFee,
      _reduceOnly: false,
      _tpToken: address(wbtc)
    });

    // Time passed for 60 seconds
    skip(60);

    // T11: Btc Price has changed to 18,500 USD
    //      Should revert ILimitTradeHandler_InvalidPriceForExecution
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 18_500 * 1e8, 0);
    tickPrices[1] = 98260;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp,
      signature: "ILimitTradeHandler_InvalidPriceForExecution()"
    });

    // T12: Btc Price has changed to 17,950 USD
    //      Execute Bob order index 0
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 17_950 * 1e8, 0);
    tickPrices[1] = 97958;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 0,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp
    });
    {
      // When Limit order index 0 has executed
      // Then Bob should has Long position
      // And Position size should be 3000 USD at Price 18000 USD

      // Given Oracle price   = 17950 USD
      // And TVL
      //  - BTC               = 0.99827923 * 17950 = 17919.1121785
      //  - Total             = 17919.1121785 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 0
      // new Market skew      = 0 + 3000 (long position)
      // Premium before       = 0 / 300000000 = 0
      // Premium after        = 3000 / 300000000 = 0.00001
      // Premium median       = (0 + 0.00001) / 2 = 0.000005
      // Adaptive price       = 17950 * (1 + 0.000005) = 18000.07999995
      //                      = 18000.07999995

      // Market's Funding rate calculation
      // When Market skew is 0
      // Then Funding rate is 0
      assertMarketFundingRate(wbtcMarketIndex, 0, 1420, "T12: ");

      // Crypto Borrowing rate calculation
      // Given Latest info
      //    Reserve                 = 13.5 USD
      //    Sum borrowing rate      = 0.000008124373119358
      //    Latest borrowing time   = 1180
      // And Time passed            = 1420 - 1180 = 240 seconds (240 intervals)
      // Then
      //    Pending borrowing rate  = 13.5 * 240 * 0.01% / 17919.1121785
      //                            = 0.000018081252953410
      // And Sum borrowing rate     = 0.000008124373119358 + 0.000018081252953410
      //                            = 0.000026205626072768
      assertAssetClassSumBorrowingRate(0, 0.000026205626072768 * 1e18, 1420, "T12: ");

      // BTC market IMF       = 1%
      // BTC market MMF       = 0.5%
      // Inc / Dec Fee        = 0.1%

      // Before:
      //    Position size     = 0
      //    Avg Price         = 0
      //    Reserve           = 0
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      //    Borrowing fee     = 0
      //    Funding fee       = 0

      // After:
      //    Position size     = 3000
      //    Avg price         = 17500.0875 USD
      //    IMR               = 3000 * 1%   =  30 USD
      //    MMR               = 3000 * 0.5% =  15 USD
      //    Reserve           = 30 * 900%   = 270 USD
      //    Trading fee       = 3000 * 0.1% =   3 USD
      //    Borrowing rate    = 0.000026205626072768
      //    Funding rate      = 0

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 0

      // Given Limit price   = 18000 USD
      // And TVL
      //  - BTC               = 0.99572425 * 17500 = 17425.174375
      //  - Total             = 17425.174375 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 0
      // new Market skew      = 0 + 3000 (long position)
      // Premium before       = 0 / 300000000 = 0
      // Premium after        = 3000 / 300000000 = 0.00001
      // Premium median       = (0 + 0.00001) / 2 = 0.000005
      // Adaptive price       = 18000 * (1 + 0.000005) = 18000.09

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: 3_000 * 1e30,
        _avgPrice: 18000.09 * 1e30,
        _reserveValue: 270 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0.000026205626072768 * 1e18,
        _lastFundingAccrued: 0,
        _str: "T12: "
      });

      // BOB Sub-account's state
      //    IMR             = 0 USD
      //    MMR             = 0 USD
      // In Summarize
      //    IMR = 0 + 30    = 30 USD
      //    MMR = 0 + 15    = 15 USD

      assertSubAccountStatus({ _subAccount: _bobSubAccount0, _imr: 30 * 1e30, _mmr: 15 * 1e30, _str: "T12: " });

      // Invariant Testing
      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T12: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Bob's collateral before settle payment
      //    BTC - 0.01 btc

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00317213 btc
      //        - dev fee       = 0.00003038 btc
      //        - funding fee   = 0.00000014 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99827923 btc

      // Settlement detail
      // Bob has to pay
      //    Trading fee   - 3 USD
      //      BTC - 3 / 17950               = 0.00016713 btc
      //          - pay for dev (15%)       = 0.00002506 btc
      //          - pay for protocol (85%)  = 0.00016713 - 0.00002506
      //                                    = 0.00014207 btc

      // And HLP has to pay
      //     nothing

      // Bob's collateral after settle payment
      //    BTC - 0.01 - 0.00016713 = 0.00983287 btc

      assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.00983287 * 1e8, "T12: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00317213 + 0.00014207 = 0.00331420 btc
      //        - dev fee       = 0.00003038 + 0.00002506 = 0.00005544 btc
      //        - funding fee   = 0.00000014

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00331420 * 1e8,
        _devFee: 0.00005544 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T12: "
      });

      // HLP's liquidity after settle payment
      //    nothing changed
      assertHLPLiquidity(address(wbtc), 0.99827923 * 1e8, "T12: ");

      // Asset Market's state, Asset class's state

      assertMarketLongPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 3000 * 1e30,
        _avgPrice: 18_000.09 * 1e30,
        _str: "T12: "
      });
      // And Short side should invariant
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T12: " });

      // Assert Asset class
      // Given Crypto's reserve is 13.5
      // When Bob increase Btc position for 3000 USD
      // And reserve is 270 USD
      // Then Crypto's reserve should increased by 270 = 283.5 USD
      assertAssetClassReserve(0, 283.5 * 1e30, "T12: ");

      // Invariant testing
      assertAssetClassReserve(2, 0, "T12: ");
      assertAssetClassReserve(1, 0, "T12: ");
    }

    // T13: Bob create limit order to stop loss for 2% ~= 17,945 USD
    // Order Index: 1
    createLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _marketIndex: wbtcMarketIndex,
      _sizeDelta: -3000 * 1e30,
      _triggerPrice: 17_945 * 1e30,
      _acceptablePrice: 17496.375 * 1e30, // 17945 * (1 - 0.025) = 17496.375
      _triggerAboveThreshold: false,
      _executionFee: executionOrderFee,
      _reduceOnly: true,
      _tpToken: address(wbtc)
    });

    // Time passed for 60 seconds
    skip(60);

    // T14: Btc Price has changed to 18,000 USD
    //      Execute Bob order index 1, but price is not trigger
    //      Should revert ILimitTradeHandler_InvalidPriceForExecution
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 18_000 * 1e8, 0);
    tickPrices[1] = 97986;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp,
      signature: "ILimitTradeHandler_InvalidPriceForExecution()"
    });

    // T15: Btc Price has changed to 17_940 USD
    //      Execute Bob order index 1
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 17_940 * 1e8, 0);
    tickPrices[1] = 97952;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 1,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp
    });
    {
      // When Limit order index 1 has executed
      // Then Bob has stop loss Btc Long position would decreased by 3000 USD at price 17,945 USD

      // Given Oracle price   = 17940 USD
      // And TVL
      //  - BTC               = 0.99827923 * 17940 = 17909.1293862
      //  - Total             = 17909.1293862 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 3000
      // new Market skew      = 3000 - 0
      // Premium before       = 3000 / 300000000 = 0.00001
      // Premium after        = 0 / 300000000 = 0
      // Premium median       = (0.00001 + 0) / 2 = 0.000005
      // Adaptive price       = 17940 * (1 + 0.000005)
      //                      = 17940.0897

      // Market's Funding rate calculation
      // When Market skew is 3000
      // And Funding rate formula = -(Intervals * (Skew ratio * Max funding rate))
      // And Time passed         = 1480 - 1420 = 60 seconds (60 intervals)
      // Then Funding rate       = -(60 * (3000 / 300000000) * 0.04%)
      //                         = -0.00000024
      assertMarketFundingRate(wbtcMarketIndex, 2777777, 1480, "T15: ");

      // Crypto Borrowing rate calculation
      // Given Latest info
      //    Reserve                 = 283.5 USD
      //    Sum borrowing rate      = 0.000026205626072768
      //    Latest borrowing time   = 1420
      // And Time passed            = 1480 - 1420 = 60 seconds (60 intervals)
      // Then
      //    Pending borrowing rate  = 283.5 * 60 * 0.01% / 17909.1293862
      //                            = 0.000094979491371072
      // And Sum borrowing rate     = 0.000026205626072768 + 0.000094979491371072
      //                            = 0.000121185117443840
      assertAssetClassSumBorrowingRate(0, 0.000121185117443840 * 1e18, 1480, "T15: ");

      // BTC market IMF       = 1%
      // BTC market MMF       = 0.5%
      // Inc / Dec Fee        = 0.1%

      // Before:
      //    Position size     = 3000
      //    Avg Price         = 18000 USD
      //    Reserve           = 270 USD
      //    Borrowing rate    = 0.000026205626072768
      //    Finding rate      = -0.00000024

      // After: (close position)
      //    Position size     = 0
      //    Avg price         = 0
      //    IMR               = 0
      //    MMR               = 0
      //    Reserve           = 0
      //    Borrowing rate    = 0
      //    Funding rate      = 0

      //    Trading fee       = 3000 * 0.1% = 3 USD

      //    Borrowing fee     = 270 * (0.000121185117443840 - 0.000026205626072768)
      //                      = 0.02564446267018944 USD
      //    Funding fee       = (-0.00000024 - -(0.00000024)) * 3000
      //                      = 0 USD

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 3000 * (17945 - 18000) / 18000
      //                = -9.166666666666666666666666666666 USD

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0,
        _str: "T15: "
      });

      // BOB Sub-account's state
      //    IMR             = 30 USD
      //    MMR             = 15 USD
      // In Summarize, after close position
      //    IMR = 30 - 30   = 0 USD
      //    MMR = 15 - 15   = 0 USD

      assertSubAccountStatus({ _subAccount: _bobSubAccount0, _imr: 0, _mmr: 0, _str: "T15: " });

      // Invariant Testing
      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T15: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Bob's collateral before settle payment
      //    BTC - 0.00983287 btc

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00331420 btc
      //        - dev fee       = 0.00005544 btc
      //        - funding fee   = 0.00000014 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99827923 btc

      // Settlement detail
      // Bob has to pay
      //    Trading fee - 3 USD
      //      BTC - 3 / 17940                         = 0.00016722 btc
      //          - pay for dev (15%)                 = 0.00002508 btc
      //          - pay for protocol (85%)            = 0.00016722 - 0.00002508
      //                                              = 0.00014214 btc
      //    Borrowing fee - 0.02564446267018944 USD
      //      BTC - 0.02564446267018944 / 17940       = 0.00000142 btc
      //          - pay for dev (15%)                 = 0.00000021 btc
      //          - pay for HLP (85%)                 = 0.00000142 - 0.00000021
      //                                              = 0.00000121
      //    Funding fee - 0 USD
      //      BTC - 0.00072 / 17940                   = 0.00000004 btc
      //          - pay for funding fee (100%)        = 0.00000004 btc
      //
      //    Loss - 9.166666666666666666666666666666 USD
      //      BTC - 9.166666666666666666666666666666 / 17940
      //                                              = 0.00051096 btc
      //          - pay for HLP (100%)                = 0.00051096 btc

      // And HLP has to pay
      //      nothing

      // Bob's collateral after settle payment
      //    BTC = 0.00983287 - 0.00016722 - 0.00000142 - 0.00000004 - 0.00051096
      //        = 0.00915323 btc

      assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.00915323 * 1e8, "T15: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00331420 + 0.00014214              = 0.00345634 btc
      //        - dev fee       = 0.00005544 + 0.00002508 + 0.00000021 = 0.00008073 btc
      //        - funding fee   = 0.00000014 + 0.00000004              = 0.00000018 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00345634 * 1e8,
        _devFee: 0.00008073 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T15: "
      });

      // HLP's liquidity after settle payment
      //    BTC - 0.99827923 + 0.00000121 + 0.00051096 = 0.99879140
      assertHLPLiquidity(address(wbtc), 0.99879140 * 1e8, "T15: ");

      // Asset Market's state, Asset class's state

      assertMarketLongPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T15: " });
      // And Short side should invariant
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T15: " });

      // Assert Asset class
      // Given Crypto's reserve is 283.5
      // When Bob decrease Btc long position for 3000 USD
      // And deceased reserve is 270 USD
      // Then Crypto's reserve should decreased by 270 = 13.5 USD
      assertAssetClassReserve(0, 13.5 * 1e30, "T15: ");

      // Invariant testing
      assertAssetClassReserve(2, 0, "T15: ");
      assertAssetClassReserve(1, 0, "T15: ");
    }

    // T16: Bob create limit order sell Btc for 3000 USD at price 21,000 USD
    // Order Index: 2
    createLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _marketIndex: wbtcMarketIndex,
      _sizeDelta: -3000 * 1e30,
      _triggerPrice: 21_000 * 1e30,
      _acceptablePrice: 20475 * 1e30, // 21000 * (1 - 0.025) = 20475
      _triggerAboveThreshold: true,
      _executionFee: executionOrderFee,
      _reduceOnly: false,
      _tpToken: address(wbtc)
    });

    // Time passed for 60 seconds
    skip(60);

    // T17: Btc Price has changed to 21,500 USD
    //      Execute Bob order index 2
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 21_500 * 1e8, 0);
    tickPrices[1] = 99763;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 2,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp
    });
    {
      // When Limit order index 2 has executed
      // Then Bob would has Btc Short position size 3000 USD at price 21,000 USD

      // Given Oracle price   = 21,500 USD
      // And TVL
      //  - BTC               = 0.99879140 * 21500 = 21474.0151
      //  - Total             = 21474.0151 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 0
      // new Market skew      = 0 - 3000
      // Premium before       = 0 / 300000000 = 0
      // Premium after        = -3000 / 300000000 = -0.00001
      // Premium median       = (0 + -0.00001) / 2 = -0.000005
      // Adaptive price       = 21500 * (1 - 0.000005)
      //                      = 21499.8925 USD

      // Market's Funding rate calculation
      // When Market skew is 0
      // And Funding rate formula        = -(Intervals * (Skew ratio * Max funding rate))
      // And Time passed                = 1540 - 1480 = 60 seconds (60 intervals)
      // Then Pending Funding rate      = -(60 * (0 / 300000000) * 0.04%)
      //                                = 0
      // And Market's sum Funding rate  = -0.00000024 + 0
      assertMarketFundingRate(wbtcMarketIndex, 2777777, 1540, "T17: ");

      // Crypto Borrowing rate calculation
      // Given Latest info
      //    Reserve                 = 13.5 USD
      //    Sum borrowing rate      = 0.000121185117443840
      //    Latest borrowing time   = 1480
      // And Time passed            = 1540 - 1480 = 60 seconds (60 intervals)
      // Then
      //    Pending borrowing rate  = 13.5 * 60 * 0.01% / 21474.0151
      //                            = 0.000003772000700511
      // And Sum borrowing rate     = 0.000121185117443840 + 0.000003772000700511
      //                            = 0.000124957118144351
      assertAssetClassSumBorrowingRate(0, 0.000124957118144351 * 1e18, 1540, "T17: ");

      // BTC market IMF       = 1%
      // BTC market MMF       = 0.5%
      // Inc / Dec Fee        = 0.1%

      // Before:
      //    Position size     = 0
      //    Avg Price         = 0
      //    Reserve           = 0
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      // After: (new position)
      //    Position size     = -3000 USD
      //    Avg price         = 21,000 USD
      //    IMR               = 30
      //    MMR               = 15
      //    Reserve           = 270
      //    Borrowing rate    = 0.000124957118144351
      //    Funding rate      = -0.00000024

      //    Trading fee       = 3000 * 0.1% = 3 USD

      //    Borrowing fee     = 0
      //    Funding fee       = 0

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 0 (new position)

      // Given Limit price   = 21000 USD
      // And TVL
      //  - BTC               = 0.99572425 * 17500 = 17425.174375
      //  - Total             = 17425.174375 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 0
      // new Market skew      = 0 + 3000 (long position)
      // Premium before       = 0 / 300000000 = 0
      // Premium after        = 3000 / 300000000 = 0.00001
      // Premium median       = (0 + 0.00001) / 2 = 0.000005
      // Adaptive price       = 21000 * (1 - 0.000005) = 20999.895

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: -3_000 * 1e30,
        _avgPrice: 20999.895 * 1e30,
        _reserveValue: 270 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0.000124957118144351 * 1e18,
        _lastFundingAccrued: -2893,
        _str: "T17: "
      });

      // BOB Sub-account's state
      //    IMR             = 0 USD
      //    MMR             = 0 USD
      // In Summarize, after close position
      //    IMR = 0 + 30   = 30 USD
      //    MMR = 0 + 15   = 15 USD

      assertSubAccountStatus({ _subAccount: _bobSubAccount0, _imr: 30 * 1e30, _mmr: 15 * 1e30, _str: "T17: " });

      // Invariant Testing
      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T17: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Bob's collateral before settle payment
      //    BTC - 0.00915323 btc

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00345634 btc
      //        - dev fee       = 0.00008073 btc
      //        - funding fee   = 0.00000018 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99879139 btc

      // Settlement detail
      // Bob has to pay
      //    Trading fee - 3 USD
      //      BTC - 3 / 21500                    = 0.00013953 btc
      //          - pay for dev (15%)            = 0.00002092 btc
      //          - pay for protocol (85%)       = 0.00013953 - 0.00002092
      //                                         = 0.00011861 btc

      // And HLP has to pay
      //    nothing

      // Bob's collateral after settle payment
      //    BTC = 0.00915323 - 0.00013953
      //        = 0.0090137 btc

      assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.0090137 * 1e8, "T17: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00345634 + 0.00011861 = 0.00357495 btc
      //        - dev fee       = 0.00008073 + 0.00002092 = 0.00010165 btc
      //        - funding fee   = 0.00000018              = 0.00000018 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00357495 * 1e8,
        _devFee: 0.00010165 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T17: "
      });

      // HLP's liquidity after settle payment
      //    BTC - 0.99879140
      assertHLPLiquidity(address(wbtc), 0.99879140 * 1e8, "T17: ");

      // Asset Market's state, Asset class's state

      assertMarketLongPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T17: " });
      // And Short side should invariant
      assertMarketShortPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 3000 * 1e30,
        _avgPrice: 20999.895 * 1e30,
        _str: "T17: "
      });

      // Assert Asset class
      // Given Crypto's reserve is 283.5
      // When Bob open Btc short position for 3000 USD
      // And increase reserve as 270 USD
      // Then Crypto's reserve should increased by 270 = 283.5 USD
      assertAssetClassReserve(0, 283.5 * 1e30, "T17: ");

      // Invariant testing
      assertAssetClassReserve(2, 0, "T17: ");
      assertAssetClassReserve(1, 0, "T17: ");
    }

    // T18: Bob create stop loss order at price 22,000 USD
    // Order Index: 3
    createLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _marketIndex: wbtcMarketIndex,
      _sizeDelta: 3000 * 1e30,
      _triggerPrice: 21_500 * 1e30,
      _acceptablePrice: 22575 * 1e30, // 21500 * (1 + 0.05) = 22037.5
      _triggerAboveThreshold: true,
      _executionFee: executionOrderFee,
      _reduceOnly: true,
      _tpToken: address(wbtc)
    });

    // Time passed for 60 seconds
    skip(60);

    // T19: Btc Price has changed to 22_100 USD
    //      Execute Bob order index 2
    updatePriceData = new bytes[](1);
    // updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 22_100 * 1e8, 0);
    tickPrices[1] = 100038;
    executeLimitTradeOrder({
      _account: BOB,
      _subAccountId: 0,
      _orderIndex: 3,
      _feeReceiver: payable(FEEVER),
      _tickPrices: tickPrices,
      _publishTimeDiffs: publishTimeDiff,
      _minPublishTime: block.timestamp
    });
    {
      // When Limit order index 2 has executed
      // Then Bob fully close Btc short position at price 21500 USD

      // Given Oracle price   = 22100 USD
      // And TVL
      //  - BTC               = 0.99879140 * 22100 = 22073.28994 USD
      //  - Total             = 22073.28994 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = -3000
      // new Market skew      = -3000 + 3000
      // Premium before       = -3000 / 300000000 = -0.00001
      // Premium after        = 0 / 300000000 = 0
      // Premium median       = (-0.00001 + 0) / 2 = -0.000005
      // Adaptive price       = 22100 * (1 + -0.000005)
      //                      = 22099.8895

      // Market's Funding rate calculation
      // When Market skew is -3000
      // And Funding rate formula = -(Intervals * (Skew ratio * Max funding rate))
      // And Time passed         = 1600 - 1549 = 60 seconds (60 intervals)
      // Then Funding rate       = -(60 * (-3000 / 300000000) * 0.04%)
      //                         = 0.00000024
      // And Market's sum Funding rate  = -0.00000024 + 0.00000024
      assertMarketFundingRate(wbtcMarketIndex, 0, 1600, "T19: ");

      // Crypto Borrowing rate calculation
      // Given Latest info
      //    Reserve                 = 283.5 USD
      //    Sum borrowing rate      = 0.000124957118144351
      //    Latest borrowing time   = 1420
      // And Time passed            = 1480 - 1420 = 60 seconds (60 intervals)
      // Then
      //    Pending borrowing rate  = 283.5 * 60 * 0.01% / 22073.28994
      //                            = 0.000077061462275160
      // And Sum borrowing rate     = 0.000124957118144351 + 0.000077061462275160
      //                            = 0.000202018580419511
      assertAssetClassSumBorrowingRate(0, 0.000202018580419511 * 1e18, 1600, "T19: ");

      // BTC market IMF       = 1%
      // BTC market MMF       = 0.5%
      // Inc / Dec Fee        = 0.1%

      // Before:
      //    Position size     = -3000
      //    Avg Price         = 21000 USD
      //    Reserve           = 270 USD
      //    Borrowing rate    = 0.000124957118144351
      //    Finding rate      = -0.00000024

      // After: (close short position)
      //    Position size     = 0
      //    Avg price         = 0
      //    IMR               = 0
      //    MMR               = 0
      //    Reserve           = 0
      //    Borrowing rate    = 0
      //    Funding rate      = 0

      //    Trading fee       = 3000 * 0.1% = 3 USD

      //    Borrowing fee     = 270 * (0.000202018580419511 - 0.000124957118144351)
      //                      = 0.0208065948142932 USD
      //    Funding fee       = (0 - -(0.00000024)) * 3000
      //                      = 0.00072 USD

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 3000 * (21000 - 21500) / 21000
      //                = -71.428571428571428571428571428571 USD

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _lastFundingAccrued: 0,
        _str: "T19: "
      });

      // BOB Sub-account's state
      //    IMR             = 30 USD
      //    MMR             = 15 USD
      // In Summarize, after close position
      //    IMR = 30 - 30   = 0 USD
      //    MMR = 15 - 15   = 0 USD

      assertSubAccountStatus({ _subAccount: _bobSubAccount0, _imr: 0, _mmr: 0, _str: "T19: " });

      // Invariant Testing
      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 1.5 * 1e30, _mmr: 0.75 * 1e30, _str: "T19: " });

      // Assert Trader's balances, Vault's fees and HLP's Liquidity

      // Bob's collateral before settle payment
      //    BTC - 0.0090137 btc

      // Vault's fees before settle payment
      //    BTC - protocol fee  = 0.00357495 btc
      //        - dev fee       = 0.00010165 btc
      //        - funding fee   = 0.00000018 btc

      // HLP's liquidity before settle payment
      //    BTC - 0.99879139 btc

      // Settlement detail
      // Bob has to pay
      //    Trading fee - 3 USD
      //      BTC - 3 / 22100                       = 0.00013574 btc
      //          - pay for dev (15%)               = 0.00002036 btc
      //          - pay for protocol (85%)          = 0.00013574 - 0.00002036
      //                                            = 0.00011538 btc
      //    Borrowing fee - 0.0208065948142932 USD
      //      BTC - 0.0208065948142932 / 22100      = 0.00000094 btc
      //          - pay for dev (15%)               = 0.00000014 btc
      //          - pay for HLP (85%)               = 0.00000094 - 0.00000014
      //                                            = 0.00000080 btc
      //    Funding fee - 0.00072 USD
      //      BTC - 0.00072 / 22100                 = 0.00000003 btc
      //          - pay for funding fee (100%)      = 0.00000003 btc
      //    Loss - 71.428571428571428571428571428571 USD
      //         - 71.428571428571428571428571428571 / 22100
      //                                            = 0.00323206 btc

      // Bob's collateral after settle payment
      //    BTC = 0.0090137 - 0.00013574 - 0.00000094 - 0.00000003 - 0.00323206
      //        = 0.00564493 btc

      assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 0.00564493 * 1e8, "T19: ");

      // Vault's fees after settle payment
      //    BTC - protocol fee  = 0.00357495 + 0.00011538              = 0.00369033 btc
      //        - dev fee       = 0.00010165 + 0.00002036 + 0.00000014 = 0.00012215 btc
      //        - funding fee   = 0.00000018 + 0.00000003              = 0.00000021 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00369033 * 1e8,
        _devFee: 0.00012215 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T19: "
      });

      // HLP's liquidity after settle payment
      //    BTC = 0.99879140 + 0.00000080 + 0.00323206
      //        = 1.00202426
      assertHLPLiquidity(address(wbtc), 1.00202426 * 1e8, "T19: ");

      // Asset Market's state, Asset class's state

      assertMarketLongPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T19: " });
      // And Short side should invariant
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T19: " });

      // Assert Asset class
      // Given Crypto's reserve is 283.5
      // When Bob decrease Btc short position for 3000 USD
      // And deceased reserve is 270 USD
      // Then Crypto's reserve should decreased by 270 = 13.5 USD
      assertAssetClassReserve(0, 13.5 * 1e30, "T19: ");

      // Invariant testing
      assertAssetClassReserve(2, 0, "T19: ");
      assertAssetClassReserve(1, 0, "T19: ");
    }
  }
}
