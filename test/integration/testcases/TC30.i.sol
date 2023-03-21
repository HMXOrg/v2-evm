// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract TC30 is BaseIntTest_WithActions {
  function test_correctness_executeMultipleOrders() external {
    // T0: Initialized state
    uint256 _pythGasFee = initialPriceFeedDatas.length;

    vm.deal(ALICE, executionOrderFee);
    uint256 _aliceBTCAmount = 1e8;
    wbtc.mint(ALICE, _aliceBTCAmount);

    // Alice Create Order
    addLiquidity(ALICE, ERC20(address(wbtc)), _aliceBTCAmount, executionOrderFee, initialPriceFeedDatas, false);
    //  ALICE add 1 BTC
    //  plp Liquidity => (wbtc) 0.9970000
    // fee (wbtc) 0.003000000
    // feetotal (wbtc) 0.003000000
    // ALICE received PLP amount = 19,940.00
    // plpTotalSupply = 19,940.00

    vm.deal(ALICE, executionOrderFee);
    uint256 _aliceUSDCAmount = 20_000 * 1e6;
    usdc.mint(ALICE, _aliceUSDCAmount);
    addLiquidity(ALICE, ERC20(address(usdc)), _aliceUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);

    // ALICE add 20000 USDC
    // plp liquidity  (wbtc) 0.9970000  => (wbtc) 0.9970000, usdc(19840.0000000)
    // fee = 160 (usdc)
    // feetotal 0.003000000 (wbtc) + 160 (usdc)
    // ALICE received PLP amount = 19,840.00
    //plpTotalSupply = 39780

    uint256 _bobUSDCAmount = 0.5 * 1e6;
    vm.deal(BOB, executionOrderFee);
    usdc.mint(BOB, _bobUSDCAmount);
    addLiquidity(BOB, ERC20(address(usdc)), _bobUSDCAmount, executionOrderFee, initialPriceFeedDatas, false);

    // BOB ADD 0.5 USDC
    // LQ After fee = 0.496
    // plp liquidity (wbtc) 0.9970000, usdc(19840.0000000) => (wbtc) 0.9970000, usdc(19840.4960000)
    // fee = 0.004000000 (usdc)
    // feetotal 0.003000000 (wbtc) + 160 (usdc) => 0.003000000 (wbtc) + 160.004 (usdc)
    // BOB received PLP amount = 0.496
    // plpTotalSupply = 39780 => 39780.496

    vm.deal(BOB, executionOrderFee);
    uint256 _bobBTCAmount = 0.5 * 1e8;
    wbtc.mint(BOB, _bobBTCAmount);
    addLiquidity(BOB, ERC20(address(wbtc)), _bobBTCAmount, executionOrderFee, initialPriceFeedDatas, false);

    // BOB ADD 0.5 BTC
    // LQ After fee => 0.4996500
    // plp liquidity (wbtc) 0.9970000, usdc(19840.4960000) => (wbtc) 1.49665, usdc(19840.4960000)
    // fee => 0.000350000 (wbtc)
    // feetotal => 0.003000000 (wbtc) + 160.004 (usdc) => 0.00335 (wbtc) + 160.004 (usdc)
    // BOB received PLP amount =>  9,993.0000000
    // plpTotalSupply = 39780.496 => 49_773.496

    uint256 _lastOrderIndex = liquidityHandler.getLiquidityOrders().length - 1;
    exeutePLPOrder(_lastOrderIndex, initialPriceFeedDatas);

    assertEq(calculator.getAUME30(false) / plpV2.totalSupply() / 1e12, 1, "AUM");
    assertPLPTotalSupply(49_773.496 * 1e18);

    // assert PLP
    {
      // ALICE received PLP =>  19,940.00 +  19,840.00 => 39,780
      // BOB received PLP =>  0.496+ 9,993.0000000 => 9,993.496
      assertTokenBalanceOf(ALICE, address(plpV2), 39_780 * 1e18);
      assertTokenBalanceOf(BOB, address(plpV2), 9993.496 * 1e18);
    }

    //asert USDC
    {
      address _usdc = address(usdc);
      assertPLPLiquidity(_usdc, 19840.4960000 * 1e6);
      assertEq(vaultStorage.protocolFees(_usdc), 160.004 * 1e6, "Vault's Fee USDC is not matched");
    }

    //assert BTC
    {
      address _wbtc = address(wbtc);
      assertPLPLiquidity(_wbtc, 1.49665 * 1e8);
      assertEq(vaultStorage.protocolFees(_wbtc), 0.00335 * 1e8, "Vault's Fee WBTC is not matched");
    }

    // assert FEEVER
    uint256 nextExecutedIndex = liquidityHandler.nextExecutionOrderIndex();
    uint256 _executionFeeAddliquidity = ((executionOrderFee * nextExecutedIndex) - _pythGasFee);
    assertEq(FEEVER.balance, _executionFeeAddliquidity, "FEEVER fee");

    // END PART ADD LIQUIDITY

    // current state
    // plp liquidity => (wbtc) 1.49665, usdc(19840.4960000)
    // ALICE PLP in hand => 39,780
    // BOB PLP in hand => 9,993.496
    vm.deal(ALICE, executionOrderFee);
    removeLiquidity(ALICE, address(wbtc), 29_933 * 1e18, executionOrderFee, initialPriceFeedDatas, false);
    // ALICE REMOVE 29_933 PLP (price = 20000)
    // plpTotalSupply = 49_773.496 - 29_933(PLP) => 19840.496
    // TOKEN OUT AMOUNT BEFORE FEE => 1.49665 wbtc

    // plp liquidity  1.49665 (wbtc),19840.4960000 (usdc) =>  0 (wbtc), 19840.4960000 (usdc)
    // fee => 0.009578560 (wbtc)
    // feetotal => 0.00335 (wbtc) + 160.004 (usdc) =>  0.01292856 (wbtc)  + 160.004 (usdc)
    // ALICE received WBTC amount => 1.49665 - 0.009578560 =>  1.48707144 (wbtc)

    vm.deal(ALICE, executionOrderFee);
    removeLiquidity(ALICE, address(usdc), 9_847 * 1e18, executionOrderFee, initialPriceFeedDatas, false);
    // ALICE REMOVE 9_847 PLP (price =1)
    // plpTotalSupply = 19840.496 - 9_847(PLP) => 9,993.496
    // TOKEN OUT AMOUNT BEFORE FEE => 9,847 USDC

    // plp liquidity 19840.4960000 (usdc) => 9,993.496 (usdc)
    // fee => 0
    // feetotal => 0.01292856 (wbtc)  + 160.004 (usdc)
    // ALICE received USDC amount 9_847

    vm.deal(BOB, executionOrderFee);
    removeLiquidity(BOB, address(usdc), 9_993.496 * 1e18, executionOrderFee, initialPriceFeedDatas, false);

    // BOB REMOVE 9_993.496 PLP (price =1)
    // plpTotalSupply = 9,993.496- 9,993.496(PLP) = 0
    // TOKEN OUT AMOUNT BEFORE FEE => 9_993.496

    // plp liquidity  9,993.496 (usdc) => 0 (usdc)
    // fee => 0 because it's 100% pool weight 5% => reduce make it better
    // feetotal => 0.01292856 (wbtc)  + 160.004 (usdc)
    // BOB received USDC amount => 9_993.496

    // SUMMARY
    // ALICE get 1.48707144 (wbtc) + 9_847 (usdc)
    // BOB get 9_993.496 (usdc)
    // feetotal => 0.01292856 (wbtc)  + 160.004 (usdc)

    _lastOrderIndex = liquidityHandler.getLiquidityOrders().length - 1;
    exeutePLPOrder(_lastOrderIndex, initialPriceFeedDatas);

    nextExecutedIndex = liquidityHandler.nextExecutionOrderIndex();

    //execute 3 orders

    uint256 _executionFeeTotal = _executionFeeAddliquidity + (3 * executionOrderFee) - _pythGasFee;
    // END PART REMOVE LIQUIDITY

    assertPLPTotalSupply(0);

    assertEq(calculator.getAUME30(false), 0, "AUM");

    assertPLPLiquidity(address(wbtc), 0);
    assertPLPLiquidity(address(usdc), 0);

    assertEq(nextExecutedIndex, 7, "nextExecutionOrder Index");
    assertTokenBalanceOf(address(liquidityHandler), address(wbtc), 0);
    assertTokenBalanceOf(address(liquidityHandler), address(usdc), 0);

    assertEq(FEEVER.balance, _executionFeeTotal, "FEEVER fee");

    //assert btc
    {
      address _wbtc = address(wbtc);
      // alice remove 29_933 plp into wbtc
      assertTokenBalanceOf(ALICE, _wbtc, 1.48707144 * 1e8);
      //bob remove liquidity in usdc only
      assertTokenBalanceOf(BOB, _wbtc, 0);
      assertEq(vaultStorage.protocolFees(_wbtc), 0.01292856 * 1e8, "Vault's Fee WBTC is not matched");
    }

    //assert usdc
    {
      address _usdc = address(usdc);
      assertTokenBalanceOf(ALICE, _usdc, 9_847 * 1e6);
      assertTokenBalanceOf(BOB, _usdc, 9_993.496 * 1e6);
      assertEq(vaultStorage.protocolFees(_usdc), 160.004 * 1e6, "Vault's Fee USDC is not matched");
    }
  }
}
