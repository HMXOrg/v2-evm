// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

contract TC02 is BaseIntTest_WithActions {
  //  TC02 - trader could take profit both long and short position
  //   Prices:
  //     WBTC - 20,000 USD
  //     WETH -  1,500 USD
  //     JPY  - 136.123 (USDJPY) => 0.007346297099
  function testCorrectness_TC2_TradeWithTakeProfitScenario() external {
    vm.deal(BOB, 1 ether); // mint native token for BOB 1 ether
    wbtc.mint(BOB, 100 * 1e8); // mint btc for BOB 100 BTC

    // T1: BOB provide liquidity as WBTC 1 token
    // price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0), 0);

    // BOB provide 1 WBTC with 0.3% deposit fee
    // Then BOB receive PLP value in 20,000 * 99.7% = 19,940 USD
    // Fee = 0.003;
    assertPLPTotalSupply(19_940 * 1e18);
    assertPLPLiquidity(address(wbtc), (1 - 0.003) * 1e8);
    assertVaultTokenBalance(address(wbtc), 1 * 1e8);
    assertVaultsFees({ _token: address(wbtc), _fee: 0.003 * 1e8, _fundingFee: 0, _devFee: 0 });
    assertAccountTokenBalance(BOB, address(wbtc), 99 * 1e8);

    //   Steps (market):
    //   - alice deposit BTC 200 USD
    //   - open weth long position with 200,000 USD (1000x) - revert poor
    //   - open weth long position with 300 USD
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
