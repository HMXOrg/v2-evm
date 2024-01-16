// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract TC36 is BaseIntTest_WithActions {
  function testCorrectness_TC36_MaxUtilization() external {
    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wethMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;

    configStorage.setMarketConfig(wethMarketIndex, _marketConfig, false, 0);

    // Remove max weight from WBTC for testing purpose
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(wbtc);
    IConfigStorage.HLPTokenConfig[] memory _hlpTokenConfig = new IConfigStorage.HLPTokenConfig[](1);
    _hlpTokenConfig[0] = IConfigStorage.HLPTokenConfig({
      targetWeight: 0.95 * 1e18,
      bufferLiquidity: 0,
      maxWeightDiff: 100000 * 1e18,
      accepted: true
    });
    configStorage.addOrUpdateAcceptedToken(_tokens, _hlpTokenConfig);

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(
      ALICE,
      ERC20(address(wbtc)),
      100 * 1e8,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 100_000 * 1e6);

    addLiquidity(
      ALICE,
      ERC20(address(usdc)),
      100_000 * 1e6,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );

    {
      // HLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertHLPTotalSupply(2_094_000 * 1e18);
      // assert HLP
      assertTokenBalanceOf(ALICE, address(hlpV2), 2_094_000 * 1e18);
      assertHLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertHLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    // Retrieve the global state

    //  Calculation for Deposit Collateral and Open Position
    //  total usd debt => (99.7*20_000) + 100_000 => 2093835.07405663
    //  max utilization = 80% = 2093835.07405663 *0.8 = 1675068.0592453

    // - reserveValue = imr * maxProfit/BPS
    // - imr = reserveValue /maxProfit * BPS
    // - imr = 1675068.0592453 / 90000 * 10000 =>  1675068.0592453 /9 => 186118.67324948
    // - open position Size = imr * IMF / BPS
    // - open position Size = imr * 100 => 186118.67324948 * 100 => 18611867.324948 => 18_611_867.324948
    // - deposit collateral = sizeDelta + (sizeDelta * tradingFeeBPS / BPS)
    // - deposit collateral = 18_613_333 + (18_613_333 * 10/10000)
    // - deposit collateral = 18631946.333

    usdc.mint(BOB, 18_631_946.333 * 1e6);
    depositCollateral(BOB, 0, ERC20(address(usdc)), 18_631_946.333 * 1e6);

    uint256 _pythGasFee = initialPriceFeedDatas.length;
    vm.deal(BOB, _pythGasFee);
    vm.deal(BOB, 1 ether);
    console.log("tvl", calculator.getHLPValueE30(true));
    marketBuy(BOB, 0, wethMarketIndex, 18_611_867 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);

    {
      IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(_marketConfig.assetClass);
      IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
      // from above input reserve have to nearly with 80% of utilization
      // imr = positionSize * IMF_BPS / BPS
      // imr => 18_613_333 *1e30 / 100 => 186133330000000000000000000000000000
      // reserveValue = 186133330000000000000000000000000000 *9 =>  1675199970000000000000000000000000000

      // MaxUtilization from above 1_675_200 *1e30 => 1675200000000000000000000000000000000

      uint256 _hlpTVL = calculator.getHLPValueE30(false);
      uint256 _maxUtilizationValue = (_hlpTVL * _liquidityConfig.maxHLPUtilizationBPS) / 10000;

      assertApproxEqRel(
        _globalState.reserveValueE30,
        1675199970000000000000000000000000000,
        MAX_DIFF,
        "Global Reserve"
      );
      assertApproxEqRel(
        _assetClass.reserveValueE30,
        1675199970000000000000000000000000000,
        MAX_DIFF,
        "AssetClass's Reserve"
      );
      assertApproxEqRel(_hlpTVL, 2094000000000000000000000000000000000, MAX_DIFF, "HLP TVL");
      assertApproxEqRel(_maxUtilizationValue, 1675200000000000000000000000000000000, MAX_DIFF, "MaxUtilizationValue");
    }

    vm.deal(ALICE, executionOrderFee);
    uint256 _hlpAliceBefore = hlpV2.balanceOf(ALICE);

    // ETH Price moved up to 1,550 USD. This will make Alice's Long ETH position profitable.
    tickPrices[0] = 73463; // ETH Price 1,550 USD
    // Global Pnl will be -620559.75868551
    // Alice will be able to remove liquidity with All of her HLP - 1 HLP
    // (The 1 HLP left is there to prevent tiny share error. This is checked in the smart contract)
    // Alice HLP balance = 2093835.07405663 HLP
    // Withdrawable HLP = 2093835.07405663 - 1 = 2093834.07405663 HLP
    // Current HLP AUM = 2093835.07405663 - 620559.75868551 = 1473275.31537112 USD
    // Current HLP Total Supply = 2094000 HLP
    // HLP Price = 1473275.31537112 / 2094000 = 0.70356987 USD

    // Alice will try to remove liquidity with 2093834.07405663 HLP
    // It should pass and Bob's position should still be able to collect the profit.
    removeLiquidity(
      ALICE,
      address(wbtc),
      _hlpAliceBefore - 1e18,
      executionOrderFee,
      tickPrices,
      publishTimeDiff,
      block.timestamp,
      true
    );
    uint256 _hlpAliceAfter = hlpV2.balanceOf(ALICE);

    {
      assertEq(_hlpAliceAfter, 1e18);
      assertHLPTotalSupply(1e18);
      assertTokenBalanceOf(ALICE, address(hlpV2), 1e18);
      // BTC price = 19998.3457779 USD
      // Withdrawn value = 2093834.07405663 * 0.70356987 = 1473158.56728559 USD
      // In BTC = 1473158.56728559 / 19998.3457779 =~ 73.66982389 BTC
      // Remaining BTC before withdrawal = 99.7 BTC
      // Remaining BTC in HLP = 99.7 - 73.66982389 = 26.03017611 BTC
      assertHLPLiquidity(address(wbtc), 26.03017611 * 1e8);
      assertHLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    // Bob close this position and should settle with a profit of 620559.75868551 USD
    vm.warp(block.timestamp + 30);
    marketSell(BOB, 0, wethMarketIndex, 18_611_867 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);

    {
      assertHLPTotalSupply(1e18);
      assertTokenBalanceOf(ALICE, address(hlpV2), 1e18);
      // Remaining BTC = 26.03017611 * 19998.3457779 = 520560.46250741 USD
      // BTC should be depleted
      assertHLPLiquidity(address(wbtc), 0);
      // Unrealized PnL = 620559.75868551 - 520560.46250741 = 99999.2961781
      // Remaining USDC before closing position = 100000 USDC
      // Remaining USDC after = 100000 - 99999.2961781 = 0.7038219 USDC
      // HLP is almost depleted here.
      // However, BOB will be paying ~ 12208.001157 USDC for Borrowing Fee, Trading Fee and Funding Fee.
      assertHLPLiquidity(address(usdc), 12208.001157 * 1e6);
    }
  }
}
