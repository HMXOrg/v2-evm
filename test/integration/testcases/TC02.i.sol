// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

contract TC02 is BaseIntTest_WithActions {
  // TC02 - trader could take profit both long and short position
  // Prices:
  //    WBTC - 20,000 USD
  //    WETH -  1,500 USD
  //    JPY  - 136.123 (USDJPY) => 0.007346297099
  // Environment
  //    Add liquidity fee - 0.3%
  //    Max Profit        - 900%
  // Market info
  //    WETH - IMF 1%, MMF 0.5%
  function testCorrectness_TC2_TradeWithTakeProfitScenario() external {
    // prepare token for wallet

    // mint native token
    vm.deal(BOB, 1 ether);
    vm.deal(ALICE, 1 ether);

    // mint BTC
    wbtc.mint(ALICE, 100 * 1e8);
    wbtc.mint(BOB, 100 * 1e8);

    // T1: BOB provide liquidity as WBTC 1 token
    // note: price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0));

    // ------------------------------------------
    // | PLP's info                             |
    // | -------------------------------------- |
    // | Total supply | 19,940 TOKENs           |
    // ------------------------------------------

    // ----------------------------------------------------
    // | Liquidity's info                                 |
    // | ------------------------------------------------ |
    // | PLP    | Token   | Liquidity   | Total Liquidity |
    // | ------ | ------- | ----------- | --------------- |
    // | BOB    | WBTC    | 0.997 BTC   | 0.997 BTC       |
    // | --------------------------------------------------

    // --------------------------------------------------------------------
    // | Vault's Info                                                     |
    // | ---------------------------------------------------------------- |
    // | Token  | Total amount | Balance |    Fee | Dev fee | Funding fee |
    // | ------ | ------------ | ------- | ------ | ------- | ----------- |
    // | WBTC   |           1  |       1 |   0.03 |       0 |           0 |
    // --------------------------------------------------------------------

    assertPLPTotalSupply(19_940 * 1e18);
    assertVaultTokenBalance(address(wbtc), 1 * 1e8);
    assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _fundingFee: 0, _devFee: 0 });
    assertPLPLiquidity(address(wbtc), 0.997 * 1e8);
    // check to prove transfer corrected amount from liquidity provider
    assertTokenBalanceOf(BOB, address(wbtc), 99 * 1e8);

    // Steps (market):

    // T2: alice deposit BTC 200 USD at price 20,000
    // 200 / 20000 = 0.01 BTC
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    depositCollateral(ALICE, 0, wbtc, 0.01 * 1e8);

    // --------------------------------------------------------------------
    // | Vault's Info                                                     |
    // | ---------------------------------------------------------------- |
    // | Token  | Total amount | Balance |    Fee | Dev fee | Funding fee |
    // | ------ | ------------ | ------- | ------ | ------- | ----------- |
    // | WBTC   |         1.01 |    1.01 |   0.03 |       0 |           0 |
    // --------------------------------------------------------------------

    // -----------------------------------------------------------------------------------
    // | Trader's Collateral                                                             |
    // | ------------------------------------------------------------------------------- |
    // | Account  | Sub-account's ID | Token    | Balance | Collat Factor | Collat Value |
    // | -------- | ---------------- | -------- | ------- | ------------- | ------------ |
    // | ALICE    |               0  | WBTC     |    0.01 |           0.8 |          160 |
    // -----------------------------------------------------------------------------------

    // -----------------------------------------------------
    // | Sub-account's Status                              |
    // | ------------------------------------------------- |
    // | Sub-account |    IMR |    MMR | Free Collat (USD) |
    // | ----------- | ------ | ------ | ----------------- |
    // | ALICE-0     |      0 |      0 |               160 |
    // -----------------------------------------------------

    // prove liquidity info not changed once deposit collateral
    assertPLPTotalSupply(19_940 * 1e18);
    assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _fundingFee: 0, _devFee: 0 });
    assertPLPLiquidity(address(wbtc), 0.997 * 1e8);

    // + 0.01 from deposit collateral
    assertVaultTokenBalance(address(wbtc), 1.01 * 1e8);

    // sub-account's stuff
    assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 0.01 * 1e8);
    assertSubAccounStatus({ _subAccount: _aliceSubAccount0, _freeCollateral: 160 * DOLLAR, _imr: 0, _mmr: 0 });

    // check to prove transfer corrected amount from trader
    assertTokenBalanceOf(ALICE, address(wbtc), 99.99 * 1e8);

    // T3: ALICE market buy weth with 200,000 USD (1000x) at price 20,000 USD
    // should revert InsufficientFreeCollateral
    // note: price has no changed0
    vm.expectRevert(abi.encodeWithSignature("ITradeService_InsufficientFreeCollateral()"));
    marketBuy(ALICE, 0, wethMarketIndex, 200_000 * DOLLAR, address(0), new bytes[](0));

    // T4: ALICE market buy weth with 300 USD at price 20,000 USD
    // initialPriceFeedDatas is from
    marketBuy(ALICE, 0, wethMarketIndex, 300 * DOLLAR, address(0), new bytes[](0));

    // ------------------------------------------------------------------------------------------------------------
    // | Adaptive price's table                                                                                   |
    // ---------------------------------------------------------------------------------------------------------- |
    // | Asset | Pyth Price | Adaptive price | Max Screw |  Market Screw  |  Premium discount |      Price        |
    // ---------------------------------------------------------------------------------------------------------- |
    // |       |            |                |           | Before | After | Before | After    | Before | After    |
    // | ----- | ---------- | -------------- | --------- | ------ | ----- | ------ | -------- | ------ | -------- |
    // | WETH  |      1,500 |      1,500.075 | 3,000,000 | 0      | +300  |      0 | 0.0001   | 1,500  | 1,500.15 |
    // ------------------------------------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------------
    // | Position's Info                                                                    |
    // | ---------------------------------------------------------------------------------- |
    // | Sub-account | Market | Direction | Size | IMR | MMR | Avg price   | OI   | Reserve |
    // | ----------- | ------ | --------- | ---- | --- | --- | ----------- | ---- | ------- |
    // | ALICE-0     | WETH   | LONG      |  300 |   3 | 1.5 | 1,500.075   |  0.2 |      27 |
    // --------------------------------------------------------------------------------------

    // -----------------------------------------------------
    // | Sub-account's Status                              |
    // | ------------------------------------------------- |
    // | Sub-account |    IMR |    MMR | Free Collat (USD) |
    // | ----------- | ------ | ------ | ----------------- |
    // | ALICE-0     |      3 |    1.5 |               160 |
    // -----------------------------------------------------

    assertPositionInfoOf({
      _subAccount: _aliceSubAccount0,
      _marketIndex: wethMarketIndex,
      _positionSize: int256(300 * DOLLAR), // positive for LONG position
      _avgPrice: (1_500_075 * DOLLAR) / 1e3, // 1,500.075
      _openInterest: 0.19999 * 1e8, // after change OI to e18 should assert => 0.1999900000049999
      _reserveValue: 27 * DOLLAR
    });

    //   - alice withdraw 200 USD - revert
    //   - weth pump price up 5% (1650 USD)
    //   - partial close position for 150 USD
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
