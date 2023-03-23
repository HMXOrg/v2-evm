// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

contract TC02 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // TC02 - trader could take profit both long and short position
  function testCorrectness_TC2_TradeWithTakeProfitScenario() external {
    // prepare token for wallet

    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // warp to block timestamp 1000
    vm.warp(1000);

    // T1: BOB provide liquidity as WBTC 1 token
    // note: price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0), true);
    {
      // When Bob provide 1 BTC as liquidity
      assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8, "T1: ");

      // Then Bob should pay fee for 0.3% = 0.003 BTC

      // Assert PLP Liquidity
      //    BTC = 0.997 (amount - fee)
      assertPLPLiquidity(address(wbtc), 0.997 * 1e8, "T1: ");

      // When PLP Token price is 1$
      // Then PLP Token should Mint = 0.997 btc * 20,000 USD = 19,940 USD
      //                            = 19940 / 1 = 19940 Tokens
      assertPLPTotalSupply(19_940 * 1e18, "T1: ");

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
      // note: token balance is including all liquidity, dev fee and protocal fee
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

      // And PLP total supply and Liquidity must not be changed
      // note: data from T1
      assertPLPTotalSupply(19_940 * 1e18, "T2: ");
      assertPLPLiquidity(address(wbtc), 0.997 * 1e8, "T2: ");

      // And Alice should not pay any fee
      // note: vault's fees should be same with T1
      assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _devFee: 0, _fundingFeeReserve: 0, _str: "T2: " });
    }

    // time passed for 60 seconds
    skip(60);

    // T3: ALICE market buy weth with 200,000 USD (1000x) at price 20,000 USD
    // should revert InsufficientFreeCollateral
    // note: price has no changed
    vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
    marketBuy(ALICE, 0, wethMarketIndex, 200_000 * 1e30, address(0), new bytes[](0));

    // T4: ALICE market buy weth with 300 USD at price 20,000 USD
    //     Then Alice should has Long Position in WETH market
    // initialPriceFeedDatas is from
    marketBuy(ALICE, 0, wethMarketIndex, 300 * 1e30, address(0), new bytes[](0));
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

      // WETH market IMF      = 0.1%
      // WETH market MMF      = 0.05%
      // Inc / Dec Fee        = 0.1%
      // Position size        = 300 USD
      // Open interest        = 300 USD / oracle price
      //                      = 300 / 1500 = 0.2
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
        _openInterest: 0.2 * 1e8,
        _reserveValue: 27 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0,
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
      // and PLP's liquidity
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
      // and PLP's liquidity still be
      //    BTC - 0.997 btc
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301275 * 1e8,
        _devFee: 0.00000225 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T4: "
      });

      assertPLPLiquidity(address(wbtc), 0.997 * 1e8, "T4: ");

      // Assert Market
      assertMarketLongPosition(wethMarketIndex, 300 * 1e30, 1_500.00075 * 1e30, 0.2 * 1e8, "T4: ");
      assertMarketShortPosition(wethMarketIndex, 0, 0, 0, "T4: ");
      assertMarketFundingRate(wethMarketIndex, 0, 1120, "T4: ");

      // Assert Asset class
      // Crypto's reserve should be increased by = 27 USD
      assertAssetClassReserve(0, 27 * 1e30, "T4: ");
      // borrowing rate still not calculated
      assertAssetClassSumBorrowingRate(0, 0, 1120, "T4: ");

      // Just prove not affected with others asset class when Market buy
      assertAssetClassReserve(1, 0, "T4: ");
      assertAssetClassSumBorrowingRate(1, 0, 0, "T4: ");
      assertAssetClassReserve(2, 0, "T4: ");
      assertAssetClassSumBorrowingRate(2, 0, 0, "T4: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T5: Alice withdraw BTC 200 USD (200 / 20000 = 0.01 BTC)
    // should revert ICrossMarginService_InsufficientBalance
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()"));
    withdrawCollateral(ALICE, 0, wbtc, 0.1 * 1e8, new bytes[](0));

    // T6: Alice partial close Long position at WETH market for 150 USD
    //     WETH price 1,575 USD, then Alice should take profit ~5%
    updatePriceData = new bytes[](1);
    updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1_575 * 1e8, 0);
    marketSell(ALICE, 0, wethMarketIndex, 150 * 1e30, address(wbtc), updatePriceData);
    {
      // When Alice Sell WETH Market
      // And Alice has Long position
      // Then it means Alice decrease Long position
      // Given decrease size = 150 USD
      // WETH Price = 1575 USD

      // Then Check position Info

      // Time passed          = 60 seconds (60 intevals)
      // TVL                  = 19,940 USD

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = 300
      // new Market skew      = 300 + -(150) = 150
      // Premium before       = 300 / 300000000 = 0.000001
      // Premium after        = 150 / 300000000 = 0.0000005
      // Premium median       = (0.000001 + 0.0000005) / 2 = 0.00000075
      // Adaptive price       = 1575 * (1 + 0.00000075)
      //                      = 1575.00118125

      // Market's Funding rate
      // Funding rate         = -(Intervals * (Skew ratio * Max funding rate))
      //                      = -(60 * 300 / 300000000 * 0.0004)
      //                      = -0.000000024
      assertMarketFundingRate(wethMarketIndex, -0.000000024 * 1e18, 1180, "T6: ");

      // Crypto Borrowing rate
      //    = reserve * interval * base rate / tvl
      //    = 27 * 60 * 0.01% / 19940
      //    = 0.000008124373119358
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T6: ");

      // WETH market IMF      = 0.1%
      // WETH market MMF      = 0.05%
      // Inc / Dec Fee        = 0.1%
      // Borrowing base Rate  = 0.01%

      // Before:
      //    Position size     = 300
      //    Open interest     = 0.2
      //    Reserve           = 27 USD
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      // After:
      //    Position size     = 300 - 150 = 150
      //    Open interest     = 150 / 300 * 0.2
      //                      = 0.1
      //    Avg price         = 1500.00075 USD (not change for decrease)
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
      // unrealized PnL = 150 * (1575.00118125 - 1500.00075) / 1500.00075 = 7.500039374980312509843745078127

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: int256(150 * 1e30),
        _avgPrice: 1500.00075 * 1e30,
        _openInterest: 0.1 * 1e8,
        _reserveValue: 13.5 * 1e30,
        _realizedPnl: 7.500039374980312509843745078127 * 1e30,
        _entryBorrowingRate: 0.000008124373119358 * 1e18,
        _entryFundingRate: -0.000000024 * 1e18,
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

      // Assert Alice Sub-account's Collateral
      // According to T4, Alice's collateral balances
      //    BTC - 0.009985
      // When Alice sell WETH with 150 USD (decrease Long position)
      // And Funding rate is nagative so Short pay Long
      // Then Alice should receive funding fee

      // Then Alice has to pay
      //    Trading fee   - 0.15 USD
      //    Borrowing fee - 0.000219358074222666 USD

      // And Alice has to received
      //    Funding fee   - 0.0000036 USD
      //    Profit        - 7.500039374980312509843745078127 USD

      // Then Alice pay fee by Collateral
      //    BTC, (price: 20,000 USD)
      //      Trading fee     = 0.15 / 20000                  = 0.0000075 btc
      //      Borrowing fee   = 0.000219358074222666 / 20000  = 0.00000001 btc

      // And Alice receive funding fee from PLP
      // When PLP pay Alice by Liquidity
      //    BTC, (price: 20,000 USD)
      //      Funding fee     = 0.0000036 / 20000             = 0.00000000 (018) btc !too small
      //      Trader's profit = 7.500039374980312509843745078127 / 20000
      //                      = 0.000375 btc

      // In Summarize, Alice's collateral balances
      //    BTC - 0.009985 - 0.0000075 - 0.00000001 + 0.00000000 + 0.000375 = 0.01035249

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01035249 * 1e8, "T6: ");

      // Assert Fee distribution
      // According from T4
      // Vault's fees
      //    BTC - protocol fee  = 0.00301275 btc
      //        - dev fee       = 0.00000225 btc
      // and PLP's liquidity
      //    BTC - 0.997 btc

      // Alice paid list
      //    BTC
      //      Trading fee - 0.0000075 btc
      //        - pay for dev (15%)       = 0.00000112 btc
      //        - pay for protocol (85%)  = 0.00000112 - 0.0000075
      //                                  = 0.00000638 btc
      //      Borrowing fee - 0.00000001 btc
      //        - pay for dev (15%)       = 0.00000000 (15) btc !too small
      //        - pay for PLP (85%)       = 0.00000001 - 0
      //                                  = 0.00000001 btc

      // PLP paid list
      //    BTC
      //      Funding fee   - 0.00000000 (018) btc !too small
      //      Trader profit - 0.000375 btc

      // In Summarize Vault's fees
      //    BTC - protocol fee  = 0.00301275 + 0.00000638     = 0.00301913 btc
      //        - dev fee       = 0.00000225 + 0 + 0.00000112 = 0.00000337 btc
      // and PLP's liquidity
      //    BTC - 0.997 + 0.00000001 - 0.000375 = 0.99662501 btc

      // Assert Vault
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301913 * 1e8,
        _devFee: 0.00000337 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T6: "
      });

      assertPLPLiquidity(address(wbtc), 0.99662501 * 1e8, "T6: ");

      // Assert Market

      // Average Price Calculation
      //  Long:
      //    Market's Avg price = 1500.00075, Current price = 1575.00118125
      //    Market's PnL  = (300 * (1575.00118125 - 1500.00075)) / 1500.00075
      //                  = 15.000078749960625019687490156254
      //    Actual PnL    = Market's PnL - Realized PnL = 15.000078749960625019687490156254 - 7.500039374980312509843745078127
      //                  = 7.500039374980312509843745078127
      //    Avg Price     = Current Price * New Position size / New Position size + Actual PnL
      //                  = (1575.00118125 * 150) / (150 + 7.500039374980312509843745078127)
      //                  = 1500.000750000000000000000000000004

      assertMarketLongPosition(
        wethMarketIndex,
        150 * 1e30,
        1500.000750000000000000000000000004 * 1e30,
        0.1 * 1e8,
        "T6: "
      );
      assertMarketShortPosition(wethMarketIndex, 0, 0, 0, "T6: ");

      // Assert Asset class
      // According T4
      // Crypto's reserve is 27
      // When alice decreased position reserve should be reduced by = 13.5 USD
      // Then 27 - 13.5 = 13.5 USD
      // note: sum of borrowing rate is calculated on position info
      assertAssetClassReserve(0, 13.5 * 1e30, "T6: ");

      // Just prove not affected with others asset class when Market sell
      assertAssetClassReserve(1, 0, "T6: ");
      assertAssetClassReserve(2, 0, "T6: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T7: Alice Sell JPY Market for 6000 USD with same Sub-account
    marketSell(ALICE, 0, jpyMarketIndex, 6_000 * 1e30, address(wbtc), updatePriceData);
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

      // JPY market IMF       = 0.01%
      // JPY market MMF       = 0.005%
      // Inc / Dec Fee        = 0.03%
      // Position size        = 6000 USD
      // Open interest        = 6000 USD / oracle price
      //                      = 6000 / 0.007346297098947275625720855402
      //                      = 816738
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
        _openInterest: 816738 * 1e3,
        _reserveValue: 54 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0,
        _str: "T7: "
      });

      // Assert Alice Sub-account's Collateral
      // According to T6, Alice's collateral balances
      //    BTC - 0.01035249
      // When Alice sell JPY with 6000 USD
      // Then Alice has to pay
      //    Trading fee - 1.8 USD

      // And Alice pay fee by collateral
      //    BTC, (price: 20,000 USD)
      //      Trading fee = 1.8 / 20000 = 0.00009 btc

      // In Summarize, Alice's collateral balances
      //    BTC - 0.01035249 - 0.00009 = 0.01026249

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01026249 * 1e8, "T7: ");

      // Sub-account's state
      // According from T6
      //    IMR             =  1.5 USD
      //    MMR             = 0.75 USD
      // In Summarize
      //    IMR = 1.5 + 6   =  7.5 USD
      //    MMR = 0.75 + 3  = 3.75 USD

      assertSubAccountStatus({ _subAccount: _aliceSubAccount0, _imr: 7.5 * 1e30, _mmr: 3.75 * 1e30, _str: "T7: " });

      // Assert Fee distribution
      // According from T6
      // Vault's fees
      //    BTC - protocol fee  = 0.00301913 btc
      //        - dev fee       = 0.00000337 btc
      // and PLP's liquidity
      //    BTC - 0.99662501 btc

      // Alice paid fees list
      //    Trading fee
      //      BTC - 0.00009 btc
      //          - pay for dev (15%)       = 0.0000135 btc
      //          - pay for protocol (85%)  = 0.00009 - 0.0000135
      //                                    = 0.0000765 btc
      //    Borrowing fee = 0 USD
      //    Funding fee   = 0 USD

      // In Summarize Vault's fees
      //    BTC - protocol fee  = 0.00301913 + 0.0000765 = 0.00309563 btc
      //        - dev fee       = 0.00000337 + 0.0000135 = 0.00001687 btc
      // and PLP's liquidity
      //    BTC - 0.99662501 btc
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00309563 * 1e8,
        _devFee: 0.00001687 * 1e8,
        _fundingFeeReserve: 0,
        _str: "T7: "
      });

      assertPLPLiquidity(address(wbtc), 0.99662501 * 1e8, "T7: ");

      // Assert Market
      assertMarketLongPosition(jpyMarketIndex, 0, 0, 0, "T7: ");
      assertMarketShortPosition(
        jpyMarketIndex,
        6_000 * 1e30,
        0.007346223635976286152964598193 * 1e30,
        816738 * 1e3,
        "T7: "
      );
      assertMarketFundingRate(jpyMarketIndex, 0, 1240, "T7: ");

      // Assert Asset class
      // Forex's reserve should be increased by = 54 USD
      assertAssetClassReserve(2, 54 * 1e30, "T7: ");
      assertAssetClassSumBorrowingRate(2, 0, 1240, "T7: ");

      // Just prove not affected with others asset class when Market sell
      assertAssetClassReserve(0, 13.5 * 1e30, "T7: ");
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T7: ");

      assertAssetClassReserve(1, 0, "T7: ");
    }

    // Time passed for 60 seconds
    skip(60);

    // T8: Alice fully close JPY Short Position
    updatePriceData = new bytes[](1);
    updatePriceData[0] = _createPriceFeedUpdateData(jpyAssetId, 136.533 * 1e3, 0);
    marketBuy(ALICE, 0, jpyMarketIndex, 6_000 * 1e30, address(wbtc), updatePriceData);
    {
      // When Alice Buy JPY Market
      // And Alice has Short position
      // Then it means Alice decrease Short position
      // Given decrease size = 6000 USD (fully close)
      // And Price pump from T7 ~0.3%
      // JPY Price = 136.533 USDJPY (pyth price)
      //           = 0.007324236631437088469454271128 USD

      // Then Check position Info

      // Time passed          = 60 seconds (60 intevals)
      // TVL                  = ??? @todo - resolve TVL

      // Max Funding rate     = 0.04%
      // Max scale skew       = 300,000,000 USD
      // Market skew          = -6000
      // new Market skew      = -6000 + 6000 (short position)
      // Premium before       = -6000 / 300000000 = -0.00002
      // Premium after        = 0 / 300000000 = 0
      // Premium median       = (-0.00002 + 0) / 2 = -0.00001
      // Adaptive price       = 0.007324236631437088469454271128 * (1 + -0.00001)
      //                      = 0.007324163389070774098569576585

      // Market's Funding rate
      // Funding rate         = -(Intervals * (Skew ratio * Max funding rate))
      //                      = -(60 * -6000 / 300000000 * 0.0004)
      //                      = 0.00000048
      assertMarketFundingRate(jpyMarketIndex, 0.00000048 * 1e18, 1300, "T8: ");

      // Forex Borrowing rate
      //    = reserve * interval * base rate / tvl
      //    = 54 * 60 * 0.03% / ???
      //    = 0.972
      //    @todo calculate this again 0.000048764579969752
      assertAssetClassSumBorrowingRate(2, 0.000048764579969752 * 1e18, 1300, "T8: ");

      // JPY market IMF       = 0.01%
      // JPY market MMF       = 0.005%
      // Inc / Dec Fee        = 0.03%

      // Before:
      //    Position size     = -6000
      //    Open interest     = 816738
      //    Avg Price         = 0.007346223635976286152964598193 USD
      //    Reserve           = 54 USD
      //    Borrowing rate    = 0
      //    Finding rate      = 0

      // After:
      //    Position size     = -6000 + 6000      = 0
      //    Open interest     = 0 / 6000 * 816738 = 0
      //    Avg price         = 0 USD (fully close)
      //    IMR               = 0
      //    MMR               = 0
      //    Reserve           = 0
      //    Trading fee       = 6000 * 0.03% = 1.8 USD
      //    Borrowing rate    = 0.000048764579969752
      //    Funding rate      = 0.00000048

      //    Borrowing fee     = (0.000048764579969752 - 0) * 54 (reserve delta)
      //                      = 0.002633287318366608
      //    Funding fee       = (0.00000048 - 0) * 6000 (position size)
      //                      = 0.00288 USD

      // Profit and Loss
      // note: long position: size delta * (adaptive price - avg price) / avg price
      //       short position: size delta * (avg price - adaptive price) / avg price
      // unrealized PnL = 6000 * (0.007346223635976286152964598193 - 0.007324163389070774098569576585) / 0.007346223635976286152964598193
      //                = 18.01762211333523763485750665291 USD

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: jpyMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _openInterest: 0,
        _reserveValue: 0,
        _realizedPnl: 18.01762211333523763485750665291 * 1e30,
        _entryBorrowingRate: 0.000048764579969752 * 1e18,
        _entryFundingRate: 0.00000048 * 1e18,
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

      // Assert Alice Sub-account's Collateral
      // According to T7, Alice's collateral balances
      //    BTC - 0.01026249
      // When Alice Buy JPY with 6000 USD (close Short position)
      // And Funding rate is position so Short pay Long
      // Then Alice should pay funding fee

      // Then Alice has to pay
      //    Trading fee   - 1.8 USD
      //    Borrowing fee - 0.002633287318366608 USD
      //    Funding fee   - 0.00288 USD

      // And Alice has to received
      //    Profit        - 18.01762211333523763485750665291 USD

      // Then Alice pay fee by Collateral
      //    BTC, (price: 20,000 USD)
      //      Trading fee     = 1.8 / 20000                   = 0.00009 btc
      //      Borrowing fee   = 0.002633287318366608 / 20000  = 0.00000013 btc

      // And Alice receive funding fee from PLP
      // When PLP pay Alice by Liquidity
      //    BTC, (price: 20,000 USD)
      //      Funding fee     = 0.00288 / 20000               = 0.00000014 btc
      //      Trader's profit = 18.01762211333523763485750665291 / 20000
      //                      = 0.00090088 btc

      // In Summarize, Alice's collateral balances
      //    BTC - 0.01026249 - 0.00009 - 0.00000013 - 0.00000014 + 0.00090088 = 0.01107310

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01107310 * 1e8, "T8: ");

      // Assert Fee distribution
      // According from T7
      // Vault's fees
      //    BTC - protocol fee  = 0.00309563 btc
      //        - dev fee       = 0.00001687 btc
      // and PLP's liquidity
      //    BTC - 0.99662501 btc

      // Alice paid fees list
      //    Trading fee
      //      BTC - 0.00009 btc
      //          - pay for dev (15%)       = 0.0000135 btc
      //          - pay for protocol (85%)  = 0.00009 - 0.0000135
      //                                    = 0.0000765 btc
      //    Borrowing fee
      //      BTC - 0.00000013 btc
      //          - pay for dev (15%)       = 0.00000001 btc
      //          - pay for PLP (85%)       = 0.00000013 - 0.00000001
      //                                    = 0.00000012
      //    Funding fee
      //      BTC - 0.00000014 btc
      //          - pay for funding fee (100%) = 0.00000014 btc
      //
      // PLP paid list
      //    BTC
      //      Funding fee   - 0.00000014 btc
      //      Trader profit - 0.00090088 btc

      // In Summarize Vault's fees
      //    BTC - protocol fee  0.00309563 + 0.0000765              = 0.00317213 btc
      //        - dev fee       0.00001687 + 0.0000135 + 0.00000001 = 0.00003038 btc
      //        - funding fee   0.00000014 btc
      // and PLP's liquidity
      //    BTC - 0.99662501 + 0.00000012 - 0.00090088 = 0.99572425 btc

      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00317213 * 1e8,
        _devFee: 0.00003038 * 1e8,
        _fundingFeeReserve: 0.00000014 * 1e8,
        _str: "T8: "
      });

      assertPLPLiquidity(address(wbtc), 0.99572425 * 1e8, "T8: ");

      // Assert Market
      assertMarketLongPosition(jpyMarketIndex, 0, 0, 0, "T8: ");
      assertMarketShortPosition(jpyMarketIndex, 0, 0, 0, "T8: ");

      // Assert Asset class
      // Forex's reserve should be increased by = 54 USD
      assertAssetClassReserve(2, 0, "T8: ");

      // Just prove not affected with others asset class when Market sell
      assertAssetClassReserve(0, 13.5 * 1e30, "T8: ");
      assertAssetClassSumBorrowingRate(0, 0.000008124373119358 * 1e18, 1180, "T8: ");

      assertAssetClassReserve(1, 0, "T8: ");
    }

    //   Steps (limit):
    //   - bob deposit BTC 100 USD
    //   - bob create buy BTC position order at price 18,000 USD with 500 USD (order 0)
    //   - price BTC dump to 17,500 USD
    //   - execute order 0 - not trigger
    //   - price BTC dump to 17,999.99 USD
    //   - execute order 0 - BOB will has long position 500 USD with entry price 18,000 USD
    //   - bob create sell BTC position order at price 18,900 USD with 500 USD (order 1)
    //   - price BTC pump to 18,500 USD
    //   - execute order 1 - not trigger
    //   - price BTC pump to 18,900.01 USD
    //   - execute order 1 - BOB fully close short at 18,900 USD
    //   - bob create sell BTC position order at price 21,000 USD with 500 USD (order 2)
    //   - price BTC pump to 21,050 USD
    //   - execute order 2 - BOB will has short position 500 USD with entry price 21,000 USD
    //   - bob create buy BTC position order at price 18,900 USD with 500 USD (order 3)
    //   - price BTC dump to 17,999.99 USD
    //   - execute order 3 - BOB fully close long at 18,900 USD
  }
}
