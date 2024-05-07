// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { Deployer, ITokenSettingHelper } from "@hmx-test/libs/Deployer.sol";

contract TC45 is BaseIntTest_WithActions {
  function testCorrectness_tokenSetting() external {
    ITokenSettingHelper tokenSettingHelper = Deployer.deployTokenSettingHelper(
      address(proxyAdmin),
      address(vaultStorage),
      address(configStorage)
    );
    tradeHelper.setTokenSettingHelper(address(tokenSettingHelper));

    /**
     * T0: Initialized state
     */
    vm.warp(block.timestamp + 1);
    uint8 SUB_ACCOUNT_ID = 1;
    address SUB_ACCOUNT = getSubAccount(ALICE, SUB_ACCOUNT_ID);
    // Make LP contains some liquidity
    {
      vm.deal(BOB, 1 ether); //deal with out of gas
      vm.deal(ALICE, 1 ether); //deal with out of gas
      wbtc.mint(BOB, 10 * 1e8);
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);
    }
    // Mint tokens to Alice
    {
      // Mint WETH token to ALICE
      vm.deal(ALICE, 8 * 1e18);
      ybeth.depositETH{ value: 8 * 1e18 }(ALICE); // @note mint ybeth in value of 99_750 USD instead of 100_000 cause prevent decimal case (100_000 / 1_500 = 66.66666666666667 YbETH)
      // Mint USDC token to ALICE
      usdc.mint(ALICE, 9_000 * 1e6);
      // Mint WBTC token to ALICE
      wbtc.mint(ALICE, 0.05 * 1e8);
      // Mint USDT token to ALICE
      usdt.mint(ALICE, 1000 * 1e6);
      assertEq(ybeth.balanceOf(ALICE), 8 * 1e18, "YbETH Balance Of");
      assertEq(usdc.balanceOf(ALICE), 9_000 * 1e6, "USDC Balance Of");
      assertEq(wbtc.balanceOf(ALICE), 0.05 * 1e8, "WBTC Balance Of");
      assertEq(usdt.balanceOf(ALICE), 1000 * 1e6, "USDT Balance Of");
    }

    /**
     * T1: Alice deposits collateral
     */
    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 12,000(USD) of YbETH
      depositCollateral(ALICE, SUB_ACCOUNT_ID, MockErc20(address(ybeth)), 8 * 1e18);
      // Alice deposits 10,000(USD) of USDC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdc, 9_000 * 1e6);
      // Alice deposits 1,000(USD) of WBTC
      depositCollateral(ALICE, SUB_ACCOUNT_ID, wbtc, 0.05 * 1e8);
      // Alice deposits 1,000(USD) of USDT
      depositCollateral(ALICE, SUB_ACCOUNT_ID, usdt, 1000 * 1e6);
    }

    vm.startPrank(ALICE);
    address[] memory tokenSettings = new address[](4);
    tokenSettings[0] = address(usdc);
    tokenSettings[1] = address(usdt);
    tokenSettings[2] = address(ybeth);
    tokenSettings[3] = address(wbtc);
    tokenSettingHelper.setTokenSettings(SUB_ACCOUNT_ID, tokenSettings);
    vm.stopPrank();

    /**
     * T2: Alice sell short ETHUSD limit order at 450,000 USD (ETH price at 1500 USD)
     */
    vm.warp(block.timestamp + 1);
    {
      uint256 sellSizeE30 = 100_000 * 1e30;
      address tpToken = address(wbtc);
      // ALICE opens SHORT position with WETH Market Price = 1500 USD

      marketSell(
        ALICE,
        SUB_ACCOUNT_ID,
        wethMarketIndex,
        sellSizeE30,
        tpToken,
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );

      // Trading Fee 0.1%
      // Trading Fee = 100000 * 0.1% = 100 USD
      // USDC should be collected first
      // USDC previous balance = 9000 USDC
      // USDC new balance = 9000 - 100 = 8900 USDC
      assertEq(vaultStorage.traderBalances(SUB_ACCOUNT, address(usdc)), 8900 * 1e6);
    }

    /**
     * T3: ETHUSD priced up to 1,550 USD
     */

    // Set YbETH as the 1st token to settle fee
    vm.warp(block.timestamp + 1);
    {
      vm.startPrank(ALICE);
      tokenSettings = new address[](4);
      tokenSettings[0] = address(ybeth);
      tokenSettings[1] = address(usdt);
      tokenSettings[2] = address(usdc);
      tokenSettings[3] = address(wbtc);
      tokenSettingHelper.setTokenSettings(SUB_ACCOUNT_ID, tokenSettings);
      vm.stopPrank();
    }

    {
      //  Set Price for ETHUSD to 1,550 USD
      tickPrices[0] = 73463; // ETH tick price $1,550
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[4] = 0; // DAI tick price $1
      tickPrices[1] = 99039; // WBTC tick price $20,000
      setPrices(tickPrices, publishTimeDiff);

      uint256 sellSizeE30 = 100_000 * 1e30;
      address tpToken = address(wbtc);

      marketSell(
        ALICE,
        SUB_ACCOUNT_ID,
        wethMarketIndex,
        sellSizeE30,
        tpToken,
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );

      // Trading Fee 0.1%
      // Trading Fee = 100000 * 0.1% = 100 USD
      // YbETH should be collected first, YbETH price = 1550 USD
      // YbETH previous balance = 8 ETH (12400 USD)
      // YbETH new balance = (12400 - 100) / 1550 = 7.93548387 YbETH
      assertApproxEqRel(vaultStorage.traderBalances(SUB_ACCOUNT, address(ybeth)), 7.93548387 * 1e18, MAX_DIFF);
    }

    /**
     * T4: ETHUSD priced up to 1,600 USD
     */

    // Set only YbUSDB as token to settle, the smart contract should still handle the fee settlement properly with every tokens that the user has as collateral
    vm.warp(block.timestamp + 1);
    {
      vm.startPrank(ALICE);
      tokenSettings = new address[](1);
      tokenSettings[0] = address(ybusdb);
      tokenSettingHelper.setTokenSettings(SUB_ACCOUNT_ID, tokenSettings);
      vm.stopPrank();
    }

    {
      //  Set Price for ETHUSD to 1,550 USD
      tickPrices[0] = 73781; // ETH tick price $1,600
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[4] = 0; // DAI tick price $1
      tickPrices[1] = 99039; // WBTC tick price $20,000
      setPrices(tickPrices, publishTimeDiff);

      uint256 sellSizeE30 = 100_000 * 1e30;
      address tpToken = address(wbtc);

      marketSell(
        ALICE,
        SUB_ACCOUNT_ID,
        wethMarketIndex,
        sellSizeE30,
        tpToken,
        tickPrices,
        publishTimeDiff,
        block.timestamp
      );

      // Trading Fee 0.1%
      // Trading Fee = 100000 * 0.1% = 100 USD
      // YbETH should be collected first, because DAI which is the 1st one in the current setting is not available in ALICE account
      // and ALICE did not set any other tokens next. The smart contracts will fallback to the order in which the user deposited which is YbETH in this case.
      // YbETH price = 1600 USD
      // YbETH previous balance = 7.93548387 YbETH (12696.774192 USD)
      // YbETH new balance = (12696.774192 - 100) / 1600 = 7.87298387 YbETH
      assertApproxEqRel(vaultStorage.traderBalances(SUB_ACCOUNT, address(ybeth)), 7.87298387 * 1e18, MAX_DIFF);
    }
  }
}
