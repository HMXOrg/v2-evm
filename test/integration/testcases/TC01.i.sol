// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";
import { console } from "forge-std/console.sol";

contract TC01 is BaseIntTest_WithActions {
  function testCorrectness_AddAndRemoveLiquiditySuccess() external {
    // T0: Initialized state
    // Alice Create Order And Executor Execute Order
    /* 
    address _liquidityProvider,
    ERC20 _tokenIn,
    uint256 _amountIn,
    uint256 _executionFee,
    bytes[] memory _priceData
     */
    // T1: As a Liquidity, Alice adds 10,000 USD(GLP)
    // btc is 20_000, so use 0.5 WBTC is $10k
    // bytes32 _assetId = configStorage.tokenAssetIds[address(wbtc)];
    // configStorage.validateAcceptedLiquidityToken(address(wbtc));
    // console.log("WBTC", address(wbtc));
    // vm.deal(ALICE, 5);
    // addLiquidity(
    //   ALICE,
    //   wbtc,
    //   (5 * (10 ** configStorage.getAssetTokenDecimal(address(wbtc)))) / 10, //0.5 wbtc
    //   0,
    //   initialPriceFeedDatas
    // );
    // T2: Alice withdraws 100,000 USD with PLP
    // T3: Alice withdraws GLP 100 USD
    // T5: As a Liquidity, Bob adds 100 USD(GLP)
    // T6: Alice max withdraws 9,900 USD PLP in pools
  }
}
