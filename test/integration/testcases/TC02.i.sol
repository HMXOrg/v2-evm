// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

contract TC02 is BaseIntTest_WithActions {
  /**
      Environment Recap
      
      Prices
      WBTC - 20,000 USD
      WETH -  1,500 USD

      Config
      Add Liquidity Fee - 0.3%

      Liquidity Provider
      - BOB
      
      Trader
      - ALICE

      Target Market
      - WETH
     */
  function testCorrectness_TC2_Trade() external {
    LiquidityTester.LiquidityExpectedData memory liquidityExpectedData;

    vm.deal(BOB, 1 ether); // mint native token for BOB 1 ether
    wbtc.mint(BOB, 100 * 1e8); // mint btc for BOB 100 BTC

    // T1: BOB provide liquidity as WBTC 1 token
    // price has no changed0
    addLiquidity(BOB, wbtc, 1 * 1e8, executionOrderFee, new bytes[](0), 0);

    // BOB provide 1 WBTC with 0.3% deposit fee
    // Then BOB receive PLP value in 20,000 * 99.7% = 19,940 USD
    liquidityExpectedData.token = address(wbtc);
    liquidityExpectedData.lpTotalSupply = 19_940 * 1e18;
    liquidityExpectedData.tokenBalance = 1 * 1e8;
    liquidityExpectedData.tokenLiquidity = (1 - 0.003) * 1e8;
    liquidityExpectedData.fee = 0.003 * 1e8; // 1 btc * 0.3% = 0.003

    liquidityTester.assertLiquidityInfo(liquidityExpectedData);

    // T2: ALICE deposit WETH as collateral
    // depositCollateral({ _account: ALICE, _subAccountId: 0, _collateralToken: weth, _depositAmount: 1 ether });
  }
}
