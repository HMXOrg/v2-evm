// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { console2 } from "forge-std/console2.sol";

contract TC04_2 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  // ## TC04.2 - manage position, adjust with profit and loss
  function testCorrectness_TC04_2_AveragePriceCalculationWithDecreasePosition() external {
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

    // ### Scenario: Prepare environment
    // Given Bob provide 1 btc as liquidity
    // And Btc price is 20,000 USD
    // And APPLE price is 150 USD
    updatePriceData = new bytes[](2);
    updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 20000 * 1e8, 0);
    updatePriceData[1] = _createPriceFeedUpdateData(appleAssetId, 150 * 1e5, 0);
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, updatePriceData, true);

    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    address _bobSubAccount0 = getSubAccount(BOB, 0);

    // When Alice deposit 1 btc as Collateral
    // And Bob deposit 1 btc as Collateral
    // Then Alice should has btc balance 1 btc
    // And Bob also should has btc balance 1 btc
    depositCollateral(ALICE, 0, wbtc, 1 * 1e8);
    assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), true, 1 * 1e8, "T0: ");
    depositCollateral(BOB, 0, wbtc, 1 * 1e8);
    assertSubAccountTokenBalance(_bobSubAccount0, address(wbtc), true, 1 * 1e8, "T0: ");

    // ### Scenario: Alice & Bob open BTC position at different price
    // When Alice open long position 1,500 USD
    marketBuy(ALICE, 0, wbtcMarketIndex, 1_500 * 1e30, address(0), updatePriceData);
    {
      // Then Alice should has correct long position

      // oracle price       = 20_000
      // market skew        = 0
      // max scale          = 300000000
      // premium            = ((2 * market skew) + size delta) / (2 * max scale)
      //                    = ((2 * 0) + 1500) / (2 * 300000000) = 0.0000025
      // adaptive price     = oracle price * (1 + premium)
      //                    = 20000 * (1 + 0.0000025) = 20000.05

      // close price
      // position size      = 0
      // close premium      = ((2 * market skew) - position size) / (2 * max scale)
      //                    = ((2 * 0) - 0) / (2 * 300000000) = 0
      // close price        = oracle price * (1 + close premium)
      //                    = 20000 * (1 + 0) = 20000

      // next close price
      // new market skew    = +size delta = 0 + 1500 = 1500
      // new position size  = +size delta = 0 + 1500 = 1500
      // new close premium  = ((2 * new market skew) - position size) / (2 * max scale)
      //                    = ((2 * 1500) - 1500) / (2 * 300000000) = 0.0000025
      // next close price   = oracle price * (1 + new close premium)
      //                    = 20000 * (1 + 0.0000025) = 20000.05

      // new LONG average price
      // entry price        = 0 (new position)
      // pnl                = 0 * (20000 - 0) = 0
      // realized pnl       = size delta / position size * pnl
      //                    = 0
      // divisor            = new position size + pnl
      // new average price  = (next close price * new position size) / divisor, adaptive price if position size == 0
      //                    = 20000.05

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: int256(1500 * 1e30),
        _avgPrice: 20000.05 * 1e30,
        _reserveValue: 135 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0,
        _str: "T1: "
      });

      // And market's state should be corrected

      // new market's LONG average price
      // average price      = 0 (first position)
      // pnl                = 0 * (20000 - 0) = 0
      // actual pnl         = pnl - position realized pnl
      //                    = 0
      // divisor            = new market's position size + pnl
      //                    = 1500 + 0
      // new average price  = (next close price * new market's position size) / divisor, adaptive price if position size == 0
      //                    = 20000.05

      assertMarketLongPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 1500 * 1e30,
        _avgPrice: 20000.05 * 1e30,
        _str: "T1: "
      });
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T1: " });
    }

    // When BTC price is pump to 22,000 USD
    skip(60);
    updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 21_000 * 1e8, 0);
    // When Bob open long position 3,000 USD
    marketBuy(BOB, 0, wbtcMarketIndex, 3000 * 1e30, address(0), updatePriceData);
    {
      // Then BOB should has correct long position

      // oracle price       = 21_000
      // market skew        = 1500
      // max scale          = 300000000
      // premium            = ((2 * market skew) + size delta) / (2 * max scale)
      //                    = ((2 * 1500) + 3000) / (2 * 300000000) = 0.00001
      // adaptive price     = oracle price * (1 + premium)
      //                    = 21_000 * (1 + 0.00001) = 21000.21

      // close price
      // position size      = 0
      // close premium      = ((2 * market skew) - position size) / (2 * max scale)
      //                    = ((2 * 1500) - 0) / (2 * 300000000) = 0.000005
      // close price        = oracle price * (1 + close premium)
      //                    = 21_000 * (1 + 0.000005) = 21000.105

      // next close price
      // new market skew    = +size delta = 1500 + 3000 = 4500
      // new position size  = +size delta = 0 + 3000    = 3000
      // new close premium  = ((2 * new market skew) - position size) / (2 * max scale)
      //                    = ((2 * 4500) - 3000) / (2 * 300000000) = 0.00001
      // next close price   = oracle price * (1 + new close premium)
      //                    = 21_000 * (1 + 0.00001) = 21000.21

      // new LONG average price
      // entry price        = 0 (new position)
      // pnl                = 0 * (21000.105 - 0) / 0 = 0
      // realized pnl       = size delta / position size * pnl
      //                    = 0
      // divisor            = new position size + pnl
      // new average price  = (next close price * new position size) / divisor, adaptive price if position size == 0
      //                    = 21000.21

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: int256(3000 * 1e30),
        _avgPrice: 21000.21 * 1e30,
        _reserveValue: 270 * 1e30,
        _realizedPnl: 0,
        _entryBorrowingRate: 38687491044562,
        _entryFundingRate: -120000000000,
        _str: "T2: "
      });

      // And market's state should be corrected

      // new market's LONG average price
      // average price      = 20000.05
      // pnl                = (1500 * (21000.105 - 20000.05)) / 20000.05
      //                    = 75.003937490156274609313476716308
      // actual pnl         = pnl - position realized pnl
      //                    = 75.003937490156274609313476716308 - 0
      //                    = 75.003937490156274609313476716308
      // divisor            = new market's position size + pnl
      //                    = 4500 + 75.003937490156274609313476716308
      //                    = 4575.003937490156274609313476716308
      // new average price  = (next close price * new market's position size) / divisor, adaptive price if position size == 0
      //                    = (21000.21 * 4500) / 4575.003937490156274609313476716308
      //                    = 20655.926484697879294012208647495529

      assertMarketLongPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 4500 * 1e30,
        _avgPrice: 20655.926484697879294012208647495529 * 1e30,
        _str: "T2: "
      });
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T2: " });
    }

    // ### Scenario: Alice partail close & Bob fully close BTC positions
    // When Alice partially close BTC 300 USD (profit)
    marketSell(ALICE, 0, wbtcMarketIndex, 300 * 1e30, address(0), updatePriceData);
    {
      // Then Alice should has correct long position

      // oracle price       = 21_000
      // market skew        = 4500
      // max scale          = 300000000
      // premium            = ((2 * market skew) + size delta) / (2 * max scale)
      //                    = ((2 * 4500) + -(300)) / (2 * 300000000) = 0.0000145
      // adaptive price     = oracle price * (1 + premium)
      //                    = 21_000 * (1 + 0.0000145) = 21000.3045

      // close price
      // position size      = 1500
      // close premium      = ((2 * market skew) - position size) / (2 * max scale)
      //                    = ((2 * 4500) - 1500) / (2 * 300000000) = 0.0000125
      // close price        = oracle price * (1 + close premium)
      //                    = 21_000 * (1 + 0.0000125) = 21000.2625

      // next close price
      // new market skew    = +size delta = 4500 + (-300) = 4200
      // new position size  = +size delta = 1500 + (-300) = 1200
      // new close premium  = ((2 * new market skew) - position size) / (2 * max scale)
      //                    = ((2 * 4200) - 1200) / (2 * 300000000) = 0.000012
      // next close price   = oracle price * (1 + new close premium)
      //                    = 21_000 * (1 + 0.000012) = 21000.252

      // new LONG average price
      // entry price        = 20000.05
      // pnl                = (1500 * (21000.2625 - 20000.05)) / 20000.05
      //                    = 75.015749960625098437253906865232
      // realized pnl       = size delta / position size * pnl
      //                    = 300 / 1500 * 75.015749960625098437253906865232
      //                    = 15.003149992125019687450781373046
      // divisor            = new position size + unrealized pnl
      //                    = 1200 + (75.015749960625098437253906865232 - 15.003149992125019687450781373046)
      //                    = 1260.012599968500078749803125492186
      // new average price  = (next close price * new position size) / divisor, adaptive price if position size == 0
      //                    = (21000.252 * 1200) / 1260.012599968500078749803125492186
      //                    = 20000.040000099998750015624804689945

      assertPositionInfoOf({
        _subAccount: _aliceSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: int256(1200 * 1e30),
        _avgPrice: 20000.040000099998750015624804689945 * 1e30,
        _reserveValue: 108 * 1e30,
        _realizedPnl: 15.003149992125019687450781373046 * 1e30,
        _entryBorrowingRate: 38687491044562,
        _entryFundingRate: -120000000000,
        _str: "T3: "
      });

      // And market's state should be corrected

      // new market's LONG average price
      // average price      = 20655.926484697879294012208647495529
      // pnl                = (4500 * (21000.2625 - 20655.926484697879294012208647495529)) / 20655.926484697879294012208647495529
      //                    = 75.015374885626045302293070204065
      // actual pnl         = pnl - position realized pnl
      //                    = 75.015374885626045302293070204065 - 15.003149992125019687450781373046
      //                    = 60.012224893501025614842288831019
      // divisor            = new market's position size + pnl
      //                    = 4200 + 60.012224893501025614842288831019
      //                    = 4260.012224893501025614842288831019
      // new average price  = (next close price * new market's position size) / divisor, adaptive price if position size == 0
      //                    = (21000.252 * 4200) / 4260.012224893501025614842288831019
      //                    = 20704.414387497444070718313743274884

      assertMarketLongPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 4200 * 1e30,
        _avgPrice: 20704.414387497444070718313743274884 * 1e30,
        _str: "T3: "
      });
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T3: " });
    }

    // When BTC price is dump to 20,000 USD
    skip(60);
    updatePriceData[0] = _createPriceFeedUpdateData(wbtcAssetId, 20_000 * 1e8, 0);
    // When Bob fully close (loss)
    marketSell(BOB, 0, wbtcMarketIndex, 3_000 * 1e30, address(0), updatePriceData);
    {
      // Then BOB should has correct long position

      assertPositionInfoOf({
        _subAccount: _bobSubAccount0,
        _marketIndex: wbtcMarketIndex,
        _positionSize: 0,
        _avgPrice: 0,
        _reserveValue: 0,
        _realizedPnl: 0,
        _entryBorrowingRate: 0,
        _entryFundingRate: 0,
        _str: "T4: "
      });

      // And market's state should be corrected

      // oracle price       = 20_000
      // market skew        = 4200
      // max scale          = 300000000

      // close price
      // position size      = 0
      // close premium      = ((2 * market skew) - position size) / (2 * max scale)
      //                    = ((2 * 4200) - 3_000) / (2 * 300000000) = 0.000009
      // close price        = oracle price * (1 + close premium)
      //                    = 20_000 * (1 + 0.000009) = 20000.18

      // next close price
      // new market skew    = +size delta = 4200 + (-3000) = 1200
      // new position size  = +size delta = 3000 + (-3000) = 0
      // new close premium  = ((2 * new market skew) - position size) / (2 * max scale)
      //                    = ((2 * 1200) - 0) / (2 * 300000000) = 0.000004
      // next close price   = oracle price * (1 + new close premium)
      //                    = 20_000 * (1 + 0.000004) = 20000.08

      // average price      = 21000.21
      // pnl                = (3000 * (20000.18 - 21000.21)) / 21000.21
      //                    = -142.859999971428857140000028571142
      // realized pnl       = size delta / position size * pnl
      //                    = 3000 / 3000 * -142.859999971428857140000028571142
      //                    = -142.859999971428857140000028571142

      // new market's LONG average price
      // average price      = 20704.414387497444070718313743274884
      // pnl                = (4200 * (20000.18 - 20704.414387497444070718313743274884)) / 20704.414387497444070718313743274884
      //                    = -142.857671418871481043110508948541
      // actual pnl         = pnl - position realized pnl
      //                    = -142.857671418871481043110508948541 - (-142.859999971428857140000028571142)
      //                    = 0.002328552557376096889519622601
      // divisor            = new market's position size + pnl
      //                    = 1200 + 0.002328552557376096889519622601
      //                    = 1200.002328552557376096889519622601
      // new average price  = (next close price * new market's position size) / divisor, adaptive price if position size == 0
      //                    = (20000.08 * 1200) / 1200.002328552557376096889519622601
      //                    = 20000.041190710781452609932471927826

      assertMarketLongPosition({
        _marketIndex: wbtcMarketIndex,
        _positionSize: 1200 * 1e30,
        _avgPrice: 20000.041190710781452609932471927826 * 1e30,
        _str: "T2: "
      });
      assertMarketShortPosition({ _marketIndex: wbtcMarketIndex, _positionSize: 0, _avgPrice: 0, _str: "T2: " });
    }

    // ### Scenario: Alice & Bob open APPLE position at different price
    // When Alice open short position 1,500 USD
    marketSell(ALICE, 0, appleMarketIndex, 1_500 * 1e30, address(0), updatePriceData);
    // Then Alice should has correct short position
    // And market's state should be corrected
    // When APPLE price is pump to 165 USD

    /** 

    skip(60);
    updatePriceData[1] = _createPriceFeedUpdateData(appleAssetId, 165 * 1e5, 0);
    // When Bob open short position 6,000 USD
    marketSell(BOB, 0, appleMarketIndex, 6_000 * 1e30, address(0), updatePriceData);
    // Then Bob should has correct short position
    // And market's state should be corrected

    // ### Scenario: Alice partail close & Bob fully close APPLE positions
    // When Alice partially close APPLE 600 USD (loss)
    marketBuy(ALICE, 0, appleMarketIndex, 600 * 1e30, address(0), updatePriceData);
    // Then Alice should has correct short position
    // And market's state should be corrected
    // When APPLE price is dump to 150 USD
    skip(60);
    updatePriceData[1] = _createPriceFeedUpdateData(appleAssetId, 150 * 1e5, 0);
    // When Bob fully close (profit)
    marketBuy(ALICE, 0, appleMarketIndex, 6_000 * 1e30, address(0), updatePriceData);
    // Then Bob APPLE position should be closed
    // And market's state should be corrected

    */
  }
}
