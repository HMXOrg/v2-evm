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
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

import "forge-std/console.sol";

contract TC40 is BaseIntTest_WithActions {
  bytes[] internal updatePriceData;

  function testCorrectness_TC40_TransferCollateralSubAccount_WETH() external {
    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 100_000 * 1e6);

      // Mint collateral and gas for ALICE
      vm.deal(ALICE, 20 ether);
    }

    vm.warp(block.timestamp + 1);
    // BOB add liquidity
    addLiquidity(BOB, usdc, 100_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // Get SubAccount address
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    address _aliceSubAccount1 = getSubAccount(ALICE, 1);

    // Deposit Collateral  
    vm.warp(block.timestamp + 1); 
    depositCollateral(ALICE, 0, ERC20(address(weth)), 10 ether, true);

    // Try transfer collateral btw. subAccount
    vm.warp(block.timestamp + 1); 
    {
      transferCollateralSubAccount(ALICE, 0, 1, ERC20(address(weth)), 10 ether);
      assertSubAccountTokenBalance(_aliceSubAccount0, address(weth), false, 0);
      assertSubAccountTokenBalance(_aliceSubAccount1, address(weth), true, 10 ether);
    }

    // Market order long
    vm.warp(block.timestamp + 1);
    {
      updatePriceData = new bytes[](3);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      marketBuy(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(weth), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Try transfer collteral
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, ERC20(address(weth)), 5 ether);
    }

    // Try transfer collateral exceeds IMR
    vm.warp(block.timestamp + 1);
    {
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      transferCollateralSubAccount(ALICE, 1, 0, ERC20(address(weth)), 4.5 ether);
    }

    // Close current position
    vm.warp(block.timestamp + 1);
    {
      marketSell(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(weth), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Transfer leftover collateral to subAccount 0
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, ERC20(address(weth)), 4.5 ether);
    }
  }
  function testCorrectness_TC40_TransferCollateralSubAccount_WBTC() external {
    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 100_000 * 1e6);

      // Mint collateral for ALICE
      wbtc.mint(ALICE, 0.5 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // BOB add liquidity
    addLiquidity(BOB, usdc, 100_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // Get SubAccount address
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    address _aliceSubAccount1 = getSubAccount(ALICE, 1);

    // Deposit Collateral  
    vm.warp(block.timestamp + 1); 
    depositCollateral(ALICE, 0, wbtc, 0.5 * 1e8);

    // Try transfer collateral btw. subAccount
    vm.warp(block.timestamp + 1); 
    {
      transferCollateralSubAccount(ALICE, 0, 1, wbtc, 0.5 * 1e8);
      assertSubAccountTokenBalance(_aliceSubAccount0, address(wbtc), false, 0);
      assertSubAccountTokenBalance(_aliceSubAccount1, address(wbtc), true, 0.5 * 1e8);
    }

    // Market order long
    vm.warp(block.timestamp + 1);
    {
      updatePriceData = new bytes[](3);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      marketBuy(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Try transfer collteral
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, wbtc, 0.25 * 1e8);
    }

    // Try transfer collateral exceeds IMR
    vm.warp(block.timestamp + 1);
    {
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      transferCollateralSubAccount(ALICE, 1, 0, wbtc, 0.2 * 1e8);
    }

    // Close current position
    vm.warp(block.timestamp + 1);
    {
      marketSell(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(wbtc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Transfer leftover collateral to subAccount 0
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, ERC20(address(wbtc)), 0.2 * 1e8);
    }
  }
  function testCorrectness_TC40_TransferCollateralSubAccount_USDC() external {
    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);
      vm.deal(BOT, 10 ether);

      // Mint liquidity for BOB
      usdc.mint(BOB, 100_000 * 1e6);

      // Mint collateral for ALICE
      usdc.mint(ALICE, 10_000 * 1e6);
    }

    vm.warp(block.timestamp + 1);
    // BOB add liquidity
    addLiquidity(BOB, usdc, 100_000 * 1e6, executionOrderFee, tickPrices, publishTimeDiff, block.timestamp, true);

    // Get SubAccount address
    address _aliceSubAccount0 = getSubAccount(ALICE, 0);
    address _aliceSubAccount1 = getSubAccount(ALICE, 1);

    // Deposit Collateral  
    vm.warp(block.timestamp + 1); 
    depositCollateral(ALICE, 0, usdc, 10_000 * 1e6);

    // Try transfer collateral btw. subAccount
    vm.warp(block.timestamp + 1); 
    {
      transferCollateralSubAccount(ALICE, 0, 1, usdc, 10_000 * 1e6);
      assertSubAccountTokenBalance(_aliceSubAccount0, address(usdc), false, 0);
      assertSubAccountTokenBalance(_aliceSubAccount1, address(usdc), true, 10_000 * 1e6);
    }

    // Market order long
    vm.warp(block.timestamp + 1);
    {
      updatePriceData = new bytes[](3);
      tickPrices[1] = 99039; // WBTC tick price $20,000
      tickPrices[2] = 0; // USDC tick price $1
      tickPrices[6] = 48285; // JPY tick price $125

      marketBuy(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(usdc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Try transfer collteral
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, usdc, 5_000 * 1e6);
    }

    // Try transfer collateral exceeds IMR
    vm.warp(block.timestamp + 1);
    {
      vm.expectRevert(abi.encodeWithSignature("ICrossMarginService_WithdrawBalanceBelowIMR()"));
      transferCollateralSubAccount(ALICE, 1, 0, usdc, 4_500 * 1e6);
    }

    // Close current position
     vm.warp(block.timestamp + 1);
    {
      marketSell(ALICE, 1, wethMarketIndex, 100_000 * 1e30, address(usdc), tickPrices, publishTimeDiff, block.timestamp);
    }

    // Transfer leftover collateral to subAccount 0
    vm.warp(block.timestamp + 1);
    {
      transferCollateralSubAccount(ALICE, 1, 0, ERC20(address(usdc)), 4_500 * 1e6);
    }
  }
}
