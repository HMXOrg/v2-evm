// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";

contract TC36 is BaseIntTest_WithActions {
  function testCorrectness_TC36_MaxUtilization() external {
    // T0: Initialized state
    // ALICE as liquidity provider
    // BOB as trader
    IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);

    _marketConfig.maxLongPositionSize = 20_000_000 * 1e30;
    _marketConfig.maxShortPositionSize = 20_000_000 * 1e30;

    configStorage.setMarketConfig(wbtcMarketIndex, _marketConfig);

    // T1: Add liquidity in pool USDC 100_000 , WBTC 100
    vm.deal(ALICE, executionOrderFee);
    wbtc.mint(ALICE, 100 * 1e8);

    addLiquidity(ALICE, ERC20(address(wbtc)), 100 * 1e8, executionOrderFee, initialPriceFeedDatas, true);

    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 100_000 * 1e6);

    addLiquidity(ALICE, ERC20(address(usdc)), 100_000 * 1e6, executionOrderFee, initialPriceFeedDatas, true);
    {
      // PLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertPLPTotalSupply(2_094_000 * 1e18);
      // assert PLP
      assertTokenBalanceOf(ALICE, address(plpV2), 2_094_000 * 1e18);
      assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertPLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    // Retrieve the global state

    //  Calculation for Deposit Collateral and Open Position
    //  total usd debt => (99.7*20_000) + 100_000 => 2_094_000
    //  max utilization = 80% = 2_094_000 *0.8 = 1_675_200

    // - reserveValue = imr * maxProfit/BPS
    // - imr = reserveValue /maxProfit * BPS
    // - imr = 1_675_200 / 90000 * 10000 =>  1_675_200 /9 => 186_133.33333333334
    // - open position Size = imr * IMF / BPS
    // - open position Size = imr * 100 => 186133.33333333334 * 100 => 18_613_333.333333334 => 18_613_333
    // - deposit collateral = sizeDelta + (sizeDelta * tradingFeeBPS / BPS)
    // - deposit collateral = 18_613_333 + (18_613_333 * 10/10000)
    // - deposit collateral = 18631946.333

    usdc.mint(BOB, 18_631_946.333 * 1e6);
    depositCollateral(BOB, 0, ERC20(address(usdc)), 18_631_946.333 * 1e6);

    uint256 _pythGasFee = initialPriceFeedDatas.length;
    vm.deal(BOB, _pythGasFee);
    vm.deal(BOB, 1 ether);

    marketBuy(BOB, 0, wbtcMarketIndex, 18_613_333 * 1e30, address(wbtc), initialPriceFeedDatas);

    {
      IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(_marketConfig.assetClass);
      IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
      // from above input reserve have to nearly with 80% of utilzation
      // imr = positionSize * IMF_BPS / BPS
      // imr => 18_613_333 *1e30 / 100 => 186133330000000000000000000000000000
      // reserveValue = 186133330000000000000000000000000000 *9 =>  1675199970000000000000000000000000000

      // MaxUtilization from above 1_675_200 *1e30 => 1675200000000000000000000000000000000

      uint256 _plpTVL = calculator.getPLPValueE30(false);
      uint256 _maxUtilizationValue = (_plpTVL * _liquidityConfig.maxPLPUtilizationBPS) / 10000;

      assertEq(_globalState.reserveValueE30, 1675199970000000000000000000000000000, "Global Reserve");
      assertEq(_assetClass.reserveValueE30, 1675199970000000000000000000000000000, "AssetClass's Reserve");
      assertEq(_plpTVL, 2094000000000000000000000000000000000, "PLP TVL");
      assertEq(_maxUtilizationValue, 1675200000000000000000000000000000000, "MaxUtilizationValue");
    }

    vm.deal(ALICE, executionOrderFee);
    uint256 _plpAliceBefore = plpV2.balanceOf(ALICE);

    // Alice try to remove liquidity, but refund due to reach max utilization
    removeLiquidity(ALICE, address(wbtc), 1 * 1e18, executionOrderFee, initialPriceFeedDatas, true);
    uint256 _plpAliceAfter = plpV2.balanceOf(ALICE);

    {
      // PLP before and PLP after executed remove liquidity should be the same because platform refund due to reach max utilization
      assertEq(_plpAliceBefore, _plpAliceAfter, "Alice PLP should get refund");
      // PLP => 1_994_000.00(WBTC) + 100_000 (USDC)
      assertPLPTotalSupply(2_094_000 * 1e18);
      // assert PLP
      assertTokenBalanceOf(ALICE, address(plpV2), 2_094_000 * 1e18);
      assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertPLPLiquidity(address(usdc), 100_000 * 1e6);
    }

    // Alice able to add 1000 USDC liquidity to help reserve % better
    vm.deal(ALICE, executionOrderFee);
    usdc.mint(ALICE, 1_000 * 1e6);
    addLiquidity(ALICE, ERC20(address(usdc)), 1_000 * 1e6, executionOrderFee, initialPriceFeedDatas, true);
    {
      // wbtc 99.7 * 1e30 * 20000 => 1994000000000000000000000000000000000
      // usdc 100_997.2  * 1e30 * 1 => 100997200000000000000000000000000000
      // plpValueE30 = 2094997200000000000000000000000000000

      // PNL = -560052858364255462951685200733910932
      // WBTC   LONG         20000000000000000000000000000000000              20620444433333333333333333333320000              18613333000000000000000000000000000000             =560052858364255462951685200733910932

      // AUM = plpValueE30 -PNL + Pending Borrowing Fee;
      // AUM = 2094997200000000000000000000000000000 - (-560052858364255462951685200733910932) + 0
      // AUM = 2655050058364255462951685200733910932
      assertEq(calculator.getPLPValueE30(false), 2094997200000000000000000000000000000, "plp TVL");

      assertEq(calculator.getPendingBorrowingFeeE30(), 0, "pending Borrowing Fee");

      assertEq(calculator.getAUME30(false), 2655050058364255462951685200733910932, "AUM");

      assertPLPTotalSupply(2094786772875837506655217);

      assertTokenBalanceOf(ALICE, address(plpV2), 2094786772875837506655217);
      assertPLPLiquidity(address(wbtc), 99.7 * 1e8);
      assertPLPLiquidity(address(usdc), 100_997.2 * 1e6);
    }

    vm.deal(ALICE, executionOrderFee);
    removeLiquidity(ALICE, address(wbtc), 500 * 1e18, executionOrderFee, initialPriceFeedDatas, true);
    {
      //fee => 0.3%, liquidityRemove = 3_168_639
      // wbtc 99.66831361 * 1e30 * 20000 => 1993366272200000000000000000000000000
      // usdc 100_997.2  * 1e30 * 1 => 100997200000000000000000000000000000
      // plpValueE30 = 2094363472200000000000000000000000000

      // PNL = -560052858364255462951685200733910932
      // WBTC   LONG         20000000000000000000000000000000000              20620444433333333333333333333320000              18613333000000000000000000000000000000             =560052858364255462951685200733910932

      //  AUM =  2094363472200000000000000000000000000 - ( -560052858364255462951685200733910932) + 0

      assertEq(calculator.getPLPValueE30(false), 2094363472200000000000000000000000000, "plp TVL");

      assertEq(calculator.getPendingBorrowingFeeE30(), 0, "pending Borrowing Fee");

      assertEq(calculator.getAUME30(false), 2654416330564255462951685200733910932, "AUM");

      assertPLPTotalSupply(2094286772875837506655217);
      // assert PLP
      assertTokenBalanceOf(ALICE, address(plpV2), 2094286772875837506655217);
      assertPLPLiquidity(address(wbtc), 99.66831361 * 1e8);
      assertPLPLiquidity(address(usdc), 100_997.2 * 1e6);
    }

    //BOB close all position
    {
      _pythGasFee = initialPriceFeedDatas.length;
      vm.deal(BOB, _pythGasFee);
      vm.deal(BOB, executionOrderFee);
      marketSell(BOB, 0, wbtcMarketIndex, 18_613_333 * 1e30, address(wbtc), initialPriceFeedDatas);
    }

    {
      //from above state
      //plpValueE30 = 2654416330564255462951685200733910932
      //maxUtilization = 2654416330564255462951685200733910932 * 8000 / 10000 => 1675490777760000000000000000000000000
      IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
      IConfigStorage.MarketConfig memory _marketConfig = configStorage.getMarketConfigByIndex(wbtcMarketIndex);
      IPerpStorage.AssetClass memory _assetClass = perpStorage.getAssetClassByIndex(_marketConfig.assetClass);
      IConfigStorage.LiquidityConfig memory _liquidityConfig = configStorage.getLiquidityConfig();
      uint256 _plpTVL = calculator.getPLPValueE30(false);

      uint256 _maxUtilizationValue = (_plpTVL * _liquidityConfig.maxPLPUtilizationBPS) / 10000;

      assertEq(_globalState.reserveValueE30, 0, "Global Reserve");
      assertEq(_assetClass.reserveValueE30, 0, "Global AssetClass Reserve");
      assertEq(_plpTVL, 2094363472200000000000000000000000000, "PLP TVL");
      assertEq(_maxUtilizationValue, 1675490777760000000000000000000000000, "MaxUtilizationValue");
    }

    // Try to remove All liquidity in PLP should be success
    vm.deal(ALICE, executionOrderFee * 2);
    removeLiquidity(ALICE, address(usdc), 100_993.50130248 * 1e18, executionOrderFee, initialPriceFeedDatas, true);
    removeLiquidity(ALICE, address(wbtc), plpV2.balanceOf(ALICE), executionOrderFee, initialPriceFeedDatas, true);
    {
      assertEq(calculator.getPLPValueE30(false), 0, "plp TVL");

      assertEq(calculator.getPendingBorrowingFeeE30(), 0, "pending Borrowing Fee");

      assertEq(calculator.getAUME30(false), 0, "AUM");

      assertPLPTotalSupply(0);

      assertTokenBalanceOf(ALICE, address(plpV2), 0);
      assertPLPLiquidity(address(wbtc), 0);
      assertPLPLiquidity(address(usdc), 0);
    }
  }
}
