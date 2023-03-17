// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

contract TC02 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // TC02 - trader could take profit both long and short position
  // Prices:
  //    WBTC - 20,000 USD
  //    WETH -  1,500 USD
  //    JPY  - 136.123 (USDJPY) => 0.007346297099
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
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0));
    {
      // Check BOB balance
      assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8, "T1: ");

      // PLP's Total supply = 19,940 TOKENs
      assertPLPTotalSupply(19_940 * 1e18, "T1: ");

      // ----------------------------------------------------
      // | Liquidity's info                                 |
      // | ------------------------------------------------ |
      // | PLP    | Token   | Liquidity   | Total Liquidity |
      // | ------ | ------- | ----------- | --------------- |
      // | BOB    | WBTC    | 0.997 BTC   | 0.997 BTC       |
      // ----------------------------------------------------
      // ** Add liquidity fee - 0.3%

      assertPLPLiquidity(address(wbtc), 0.997 * 1e8, "T1: ");

      // Add liquidity fee
      //    PLP provice 1 BTC, then 1 * 0.3% = 0.003 BTC and distributed to Protocol fee

      // --------------------------------------------------------------------------
      // | Vault's Info                                                           |
      // | ---------------------------------------------------------------------- |
      // | Token  | Total amount | Balance | Protocol Fee | Dev fee | Funding fee |
      // | ------ | ------------ | ------- | ------------ | ------- | ----------- |
      // | WBTC   |            1 |       1 |        0.003 |       0 |           0 |
      // --------------------------------------------------------------------------

      assertVaultTokenBalance(address(wbtc), 1 * 1e8, "T1: ");
      assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _fundingFee: 0, _devFee: 0, _str: "T1: " });
    }

    // block.timestamp + 60
    skip(60);

    // T2: alice deposit BTC 200 USD at price 20,000
    // 200 / 20000 = 0.01 BTC
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    depositCollateral(ALICE, 0, wbtc, 0.01 * 1e8);
    {
      // Check ALICE balance
      assertTokenBalanceOf(ALICE, address(wbtc), 99.99 * 1e8, "T2: ");

      // Prove Data should not affected
      assertPLPTotalSupply(19_940 * 1e18, "T2: ");
      assertPLPLiquidity(address(wbtc), 0.997 * 1e8, "T2: ");

      // --------------------------------------------------------------------------
      // | Vault's Info                                                           |
      // | ---------------------------------------------------------------------- |
      // | Token  | Total amount | Balance | Protocol Fee | Dev fee | Funding fee |
      // | ------ | ------------ | ------- | ------------ | ------- | ----------- |
      // | WBTC   |         1.01 |    1.01 |        0.003 |       0 |           0 |
      // --------------------------------------------------------------------------

      assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _devFee: 0, _fundingFee: 0, _str: "T2: " });

      // + 0.01 from deposit collateral
      assertVaultTokenBalance(address(wbtc), 1.01 * 1e8, "T2: ");

      // -----------------------------------------------------------------------------------
      // | Trader sub-account's Collateral                                                  |
      // | ------------------------------------------------------------------------------- |
      // | Account  | Sub-account's ID | Token    | Balance | Collat Factor | Collat Value |
      // | -------- | ---------------- | -------- | ------- | ------------- | ------------ |
      // | ALICE    |               0  | WBTC     |    0.01 |           0.8 |          160 |
      // -----------------------------------------------------------------------------------
      // ** WBTC price 20,000 USD
      // ** Collateral value = 0.01 * 20,000 * 0.8 = 160 USD

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01 * 1e8, "T2: ");

      // -----------------------------------------------------
      // | Sub-account's summary                             |
      // | ------------------------------------------------- |
      // | Sub-account |    IMR |    MMR | Free Collat (USD) |
      // | ----------- | ------ | ------ | ----------------- |
      // | ALICE-0     |      0 |      0 |               160 |
      // -----------------------------------------------------
      // ** Equity = Collat value +- PnL - Borrowing rage +- Funding Rate
      // ** Free Collat = Equity - IMR

      assertSubAccounStatus({
        _subAccount: _aliceSubAccount0,
        _freeCollateral: 160 * 1e30,
        _imr: 0,
        _mmr: 0,
        _str: "T2: "
      });
    }

    // block.timestamp + 60
    skip(60);

    // T3: ALICE market buy weth with 200,000 USD (1000x) at price 20,000 USD
    // should revert InsufficientFreeCollateral
    // note: price has no changed0
    vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
    marketBuy(ALICE, 0, wethMarketIndex, 200_000 * 1e30, address(0), new bytes[](0));

    // T4: ALICE market buy weth with 300 USD at price 20,000 USD
    //     Then Alice should has Long Position in WETH market
    // initialPriceFeedDatas is from
    marketBuy(ALICE, 0, wethMarketIndex, 300 * 1e30, address(0), new bytes[](0));
    {
      // ---------------------------------------------------------
      // | Asset class's info                                    |
      // | ----------------------------------------------------- |
      // | Asset   | Reserve    | Sum Borrowing rate | timestamp |
      // | ------- | ---------- | ------------------ | --------- |
      // | Crypto  |         27 |                  0 | 1120      |
      // | Equity  |          0 |                  0 | 0         |
      // | Forex   |          0 |                  0 | 0         |
      // ---------------------------------------------------------

      // Assert AssetClass
      // Asset class check crypto
      assertAssetClassState(0, 27 * 1e30, 0, 1120, "T4: ");

      // Just prove not affected with others asset class when Market buy
      assertAssetClassState(1, 0, 0, 0, "T4: ");
      assertAssetClassState(2, 0, 0, 0, "T4: ");

      // Adaptive price calculate
      // WETH price = 1,500 USD,
      // Before:
      //    Market skew = 0
      //    Premium discount = 0 / 300,000,000 = 0
      //    Price with premium = 1500 * (1 + 0) = 1500
      // After:
      //    Market skew = Before + 300 USD = 300 USD
      //    Premium discount  = 300 / 300,000,000 = 0.000001
      //    Price with premium = 1500 * (1 + 0.000001) = 1500.0015
      // Adaptive price = (1500 + 1500.0015) / 2 = 1500.00075

      // --------------------------------------------------------------------------------------------------------------------------------------------------------
      // | Position's summary                                                                                                                                   |
      // | -----------------------------------------------------------------------------------------------------------------------------------------------------|
      // | Sub-account | Market | Direction | Size | IMR | MMR | Avg price   | OI    | Reserve | Realized PnL | Borrowing rate | Fundind Rate | Max Trading fee |
      // | ----------- | ------ | --------- | ---- | --- | --- | ----------- | ----- | ------- | ------------ | -------------- | ------------ | --------------- |
      // | ALICE-0     | WETH   | LONG      |  300 |   3 | 1.5 | 1,500.00075 |  0.2  |      27 |            0 | 0              | 0            | 0.3 USD         |
      // --------------------------------------------------------------------------------------------------------------------------------------------------------
      // ** Increase / Decrease trading fee 0.1%
      // ** Max Profit 900%, Reserve = Size * 900%
      // ** WETH Market - IMF 1%, MMF 0.5%

      // Assert Position
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

      // ------------------------------------------------------------------------------------------------------------------
      // | Market's summary                                                                                               |
      // | -------------------------------------------------------------------------------------------------------------- |
      // | Asset | Long Size | Long avg Price | Long OI   | Short Size | Short avg Price | Short OI | Funding rate | time |
      // | ----- | --------- | -------------- | --------- | ---------- | --------------- | -------- | ------------ | ---- |
      // | WETH  | 300       | 1,500.00075    | 0.2       | 0          | 0               | 0        | 0            | 1120 |
      // ------------------------------------------------------------------------------------------------------------------

      // Assert Market
      assertMarketLongPosition(wethMarketIndex, 300 * 1e30, 1_500.00075 * 1e30, 0.2 * 1e8, "T4: ");
      assertMarketShortPosition(wethMarketIndex, 0, 0, 0, "T4: ");
      assertMarketFundingRate(wethMarketIndex, 0, 1120, "T4: ");

      // Trading fee's calculation
      //    Increas position fee 0.1%, Size delta = 150 USD, then Fee * 0.1% = 0.15 USD
      //    Fee in Token = 0.3 / 20,000 = 0.000015 BTC
      //    Distribute to Vault's Dev fee (15%) = 0.00015 * 15% = 0.00000225 BTC
      //    Distribute to Vault's Protocol Fee 0.00015 - 0.0000225 = 0.0001275 BTC

      // -----------------------------------------------------------------------------
      // | Vault's Info                                                              |
      // | ------------------------------------------------------------------------- |
      // | Token  | Total amount | Balance | Protocol Fee |    Dev fee | Funding fee |
      // | ------ | ------------ | ------- | ------------ | ---------- | ----------- |
      // | WBTC   |         1.01 |    1.01 |   0.00301275 | 0.00000225 |           0 |
      // -----------------------------------------------------------------------------

      // Assert Vault
      assertVaultTokenBalance(address(wbtc), 1.01 * 1e8, "T4: ");
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301275 * 1e8,
        _devFee: 0.00000225 * 1e8,
        _fundingFee: 0,
        _str: "T4: "
      });

      // ------------------------------------------------------------------------------------
      // | Trader sub-account's Collateral                                                  |
      // | -------------------------------------------------------------------------------- |
      // | Account  | Sub-account's ID | Token    | Balance  | Collat Factor | Collat Value |
      // | -------- | ---------------- | -------- | -------- | ------------- | ------------ |
      // | ALICE    |               0  | WBTC     | 0.009985 |           0.8 |       159.76 |
      // ------------------------------------------------------------------------------------
      // ** WBTC price 20,000 USD
      // ** Collateral value = 0.009985 * 20,000 * 0.8 = 159.76 USD

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.009985 * 1e8, "T4: ");

      // Equity = 159.76 + (+0) - (0) + (+0) - 0.3 + 5 = 154.46
      // --------------------------------------------------------
      // | Sub-account's summary                                |
      // | ---------------------------------------------------- |
      // | Sub-account |    IMR |    MMR | Equity | Free Collat |
      // | ----------- | ------ | ------ | ------ | ----------- |
      // | ALICE-0     |      3 |    1.5 | 154.46 | 151.46      |
      // --------------------------------------------------------
      // ** Equity = Collat value +- PnL - Borrowing rage +- Funding Rate - Max Trading fee - Liquidition fee (5 USD)
      // ** Free Collat = Equity - IMR

      assertSubAccounStatus({
        _subAccount: _aliceSubAccount0,
        _freeCollateral: 151.46 * 1e30,
        _imr: 3 * 1e30,
        _mmr: 1.5 * 1e30,
        _str: "T4: "
      });
    }

    // block.timestamp + 60
    skip(60);

    // T6: Alice withdraw BTC 200 USD (200 / 20000 = 0.01 BTC)
    // should revert ICrossMarginService_InsufficientBalance
    vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_InsufficientBalance()"));
    withdrawCollateral(ALICE, 0, wbtc, 0.1 * 1e8, new bytes[](0));

    // T6: Alice partial close Long position at WETH market for 150 USD
    //     WETH price 1,575 USD, then Alice should take profit ~5%
    updatePriceData = new bytes[](1);
    updatePriceData[0] = _createPriceFeedUpdateData(wethAssetId, 1_575 * 1e8);
    marketSell(ALICE, 0, wethMarketIndex, 150 * 1e30, address(wbtc), updatePriceData);
    {
      // Adaptive price calculate
      // WETH price = 1,575 USD,
      // Before:
      //    Market skew = (0.2 - 0) * 1575 = +315 USD
      //    Premium discount = +315 / 300,000,000 = 0.00000105
      //    Price with premium = 1575 * (1 + 0.00000105) = 1,575.00165375
      // After:
      //    Market skew = Before - 150 = 165 USD
      //    Premium discount  = +165 / 300,000,000 = 0.00000055
      //    Price with premium = 1575 * (1 + 0.00000055) = 1,575.00086625
      // Adaptive price = (1,575.00165375 + 1,575.00086625) / 2 = 1,575.00126

      // Trading fee's calculation
      //    Decrease position fee 0.1%, Size delta = 150 USD, then Fee * 0.1% = 0.15 USD

      // Others Fee calculation
      // ** Funding interval 1s
      //    Intervals = 60s (timepast) / 1s = 60
      //    TVL       = 19,940 USD
      // Borrowing fee
      //  Asset class:

      // -----------------------------------------------------------------------------------------------------------
      // | Asset class's borrowing fee calculation                                                                 |
      // | ------------------------------------------------------------------------------------------------------- |
      // | Asset   | Base Rate | Reserve    | Old Borrowing rate | Pending Borrowing rate |     Sum Borrowing rate |
      // | ------- | --------- | ---------- | ------------------ | ---------------------- | ---------------------- |
      // | Crypto  |      0.01 |         27 |                  0 |   0.000008124373119358 |   0.000008124373119358 |
      // | Forex   |      0.03 |          0 |                  0 |                      0 |                      0 |
      // | Equity  |      0.02 |          0 |                  0 |                      0 |                      0 |
      // -----------------------------------------------------------------------------------------------------------
      // ** Pending borrowing rate  = Reserve * Intervals * Base fee / TVL

      // ------------------------------------------------------------------------------------------------
      // | Position's borrowing fee calculation                                                         |
      // | -------------------------------------------------------------------------------------------- |
      // | Position      | Reserve | Entry Borrowing rate | Asset's Borrowing rate | Borrowing Fee      |
      // | ------------- | ------- | -------------------- | ---------------------- | ------------------ |
      // | ALICE-0-WETH  |  27     |                    0 | 0.000008124373119358   | 0.0219358074222666 |
      // ------------------------------------------------------------------------------------------------
      // ** Borrowing fee = (Sum Borrowing rate - Entry Borrowing rate) * Reserve

      // ------------------------------------------------------------------------------------------------------------------------
      // | Market Funding fee calculation                                                                                       |
      // | -------------------------------------------------------------------------------------------------------------------- |
      // | Asset | Price      | Long OI   | Short OI | Market skew  | Skew ratio | Funding rate | Pending       | Sum           |
      // | ----- | ---------- | --------- | -------- | ------------ | ---------- | ------------ | ------------- | ------------- |
      // | WETH  |      1,575 | 0.2       | 0        | 315          | 0.00000105 | 0            | -0.0000000252 | -0.0000000252 |
      // ------------------------------------------------------------------------------------------------------------------------
      // ** Max skew = 300,000,000 USD
      // ** Market skew = (Long OI - Short OI) * Price
      // ** Skew ratio = Market skew / Max skew
      // ** Max funding rate = 0.04% --> @todo fixed
      // ** Peding Funding rate = -(Skew ratio * Max funding rate * Intervals)
      // !!! maximum funding rate [-max funding rate, max funding rate] per interval

      // ---------------------------------------------------------------------------------------------------
      // | Position's funding fee calculation                                                              |
      // | ----------------------------------------------------------------------------------------------- |
      // | Position      | Position size | Entry Funding rate | Market's funding rate | Funding Fee        |
      // | ------------- | ------------- | ------------------ | --------------------- | ------------------ |
      // | ALICE-0-WETH  | 300           |                  0 | -0.0000000252         | -0.00000756        |
      // ---------------------------------------------------------------------------------------------------
      // ** Funding fee = (Market's funding rate - Entry Funding rate) * Position size

      // Realized PnL
      //    Position size       = 300 USD
      //    Position size delta = 150 USD
      //    Position Avg price = 1,500.00075, Current price = 1,575.00126
      //    Unrealized PnL  = (Position size * (Current price - Position Avg price)) / Position Avg price
      //                    = (300 * (1,575.00126 - 1,500.00075)) / 1,500.00075
      //                    = 15.000094499952750023624988187505
      //    Realized PnL  = (Unrealized PnL * Delta) / Position size
      //                  = (15.000094499952750023624988187505 * 150) / 300
      //                  = 7.500047249976375011812494093752
      //    Settlement Fee = 0%

      // Summary Fee distribution
      //    Trading fee - 0.15 USD
      //                - 0.0000075 btc
      //                    - Dev 15%: 0.000001125
      //                    - Protocol: 0.0000075 - 0.000001125 = 0.000006375 btc
      //    Borrow fee  - 0.0219358074222666 USD
      //                - 0.00000109 btc
      //                    - Dev 15%: 0.00000016
      //                    @todo - should go to PLP
      //                    - Protocol: 0.00000109 - 0.00000016 = 0.00000093 btc
      //    Fundind fee - -0.00000756 USD (PLP pay trader)
      //                @todo - should go to PLP
      //                -

      // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      // | Position's summary                                                                                                                                                             |
      // | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
      // | Sub-account | Market | Direction | Size | IMR | MMR  | Avg price   | OI    | Reserve | Realized PnL                     | Borrowing rate     | Fundind Rate  | Max Trading fee |
      // | ----------- | ------ | --------- | ---- | --- | ---- | ----------- | ----- | ------- | -------------------------------- | ------------------ | ------------- | --------------- |
      // | ALICE-0     | WETH   | LONG      |  150 | 1.5 | 0.75 | 1500.00075  |  0.1  |    13.5 | 7.500047249976375011812494093752 | 0.0008124373119358 | -0.0000000252 | 0.15 USD        |
      // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      // ** Increase / Decrease trading fee 0.1%
      // ** Max Profit 900%, Reserve = Size * 900%
      // ** WETH Market - IMF 1%, MMF 0.5%

      // Assert Position
      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wethMarketIndex,
        _positionSize: int256(150 * 1e30),
        _avgPrice: 1500.00075 * 1e30,
        _openInterest: 0.1 * 1e8,
        _reserveValue: 13.5 * 1e30,
        _realizedPnl: 7.500047249976375011812494093752 * 1e30,
        _entryBorrowingRate: 0.000008124373119358 * 1e18,
        _entryFundingRate: -0.0000000252 * 1e18,
        _str: "T6: "
      });

      // Average Price Calculation
      //  Long:
      //    Market's Avg price = 1,500.00075, Current price = 1,575.00126
      //    Market's PnL  = (300 * (1,575.00126 - 1,500.00075)) / 1,500.00075
      //                  = 15.000094499952750023624988187505
      //    Actual PnL    = Market's PnL - Realized PnL = 15.000094499952750023624988187505 - 7.500047249976375011812494093752
      //                  = 7.500047249976375011812494093753
      //    Avg Price     = Current Price * New Position size / New Position size + Actual PnL
      //                  = (1575.00126 * 150) / (150 + 7.500047249976375011812494093753)
      //                  = 1500.000749999999999999999999999999

      // ---------------------------------------------------------------------------------------------------------------------------------------------
      // | Market's summary                                                                                                                          |
      // | ----------------------------------------------------------------------------------------------------------------------------------------- |
      // | Asset | Long Size   | Previous Avg Price | Long avg Price    | Long OI   | Short Size | Short avg Price | Short OI | Funding rate  | time |
      // | ----- | ----------- | ------------------ | ----------------- | --------- | ---------- | -------------------------- | ------------- | ---- |
      // | WETH  | 300 -> 150  | 1500.00075 / 0     | 1500.00074999.... | 0.1       | 0          | 0               | 0        | -0.0000000252 | 1180 |
      // ---------------------------------------------------------------------------------------------------------------------------------------------

      // Assert Market
      assertMarketLongPosition(
        wethMarketIndex,
        150 * 1e30,
        1500.000749999999999999999999999999 * 1e30,
        0.1 * 1e8,
        "T6: "
      );
      assertMarketShortPosition(wethMarketIndex, 0, 0, 0, "T6: ");
      assertMarketFundingRate(wethMarketIndex, -0.0000000252 * 1e18, 1180, "T6: ");

      // -----------------------------------------------------------
      // | Asset class's summary                                   |
      // | ------------------------------------------------------- |
      // | Asset   | Reserve    | Sum Borrowing rate   | timestamp |
      // | ------- | ---------- | -------------------- | --------- |
      // | Crypto  |       13.5 | 0.000008124373119358 | 1180      |
      // | Equity  |          0 |                    0 | 0         |
      // | Forex   |          0 |                    0 | 0         |
      // -----------------------------------------------------------

      // Assert AssetClass
      // Asset class check crypto
      assertAssetClassState(0, 13.5 * 1e30, 0.000008124373119358 * 1e18, 1180, "T6: ");

      // Just prove not affected with others asset class when Market sell
      assertAssetClassState(1, 0, 0, 0, "T6: ");
      assertAssetClassState(2, 0, 0, 0, "T6: ");

      // -----------------------------------------------------------------------------
      // | Vault's Info                                                              |
      // | ------------------------------------------------------------------------- |
      // | Token  | Total amount | Balance | Protocol Fee |    Dev fee | Funding fee |
      // | ------ | ------------ | ------- | ------------ | ---------- | ----------- |
      // | WBTC   |         1.01 |    1.01 |   0.00301913 | 0.00000337 |           0 |
      // -----------------------------------------------------------------------------

      // Assert Vault
      assertVaultsFees({
        _token: address(wbtc),
        _fee: 0.00301913 * 1e8,
        _devFee: 0.00000337 * 1e8,
        _fundingFee: 0,
        _str: "T6: "
      });

      // -------------------------------------------------------------------------------------
      // | Trader sub-account's Collateral                                                   |
      // | --------------------------------------------------------------------------------- |
      // | Account  | Sub-account's ID | Token    | Balance   | Collat Factor | Collat Value |
      // | -------- | ---------------- | -------- | --------- | ------------- | ------------ |
      // | ALICE    |               0  | WBTC     | 0.0099775 |           0.8 |       159.64 |
      // ------------------------------------------------------------------------------------
      // ** WBTC price 20,000 USD
      // ** Collateral value = 0.0099775 * 20,000 * 0.8 = 159.64 USD

      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.0099775 * 1e8, "T6: ");

      // Equity = 159.76 + (+0) - (0) + (+0) - 0.3 + 5 = 154.46
      // -----------------------------------------------------
      // | Sub-account's summary                             |
      // | ------------------------------------------------- |
      // | Sub-account |    IMR |    MMR | Free Collat (USD) |
      // | ----------- | ------ | ------ | ----------------- |
      // | ALICE-0     |    1.5 |   0.75 |            158.14 |
      // -----------------------------------------------------
      // ** Equity = Collat value +- PnL - Borrowing rage +- Funding Rate - Max Trading fee - Liquidition fee (5 USD)
      // ** Free Collat = Equity - IMR

      // assertSubAccounStatus({
      //   _subAccount: _aliceSubAccount0,
      //   _freeCollateral: 158.14 * 1e30,
      //   _imr: 1.5 * 1e30,
      //   _mmr: 0.75 * 1e30,
      //   _str: "T6: "
      // });
    }

    //   - alice open short JPY position 5000 USD
    //   - jpy pump price 3%
    //   - alice fully close JPY position
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
