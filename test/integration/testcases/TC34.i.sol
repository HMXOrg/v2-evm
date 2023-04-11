// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.18;

// import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

// import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

// contract TC34 is BaseIntTest_WithActions {
//   function test_correctness_swingPriceViaExecution() external {
//     // T0: Initialized state
//     uint256 _totalExecutionOrderFee = executionOrderFee - initialPriceFeedDatas.length;

//     uint256 _amount = 5e7; //0.5 btc

//     // mint 0.5 btc and give 0.0001 gas
//     vm.deal(ALICE, executionOrderFee);
//     wbtc.mint(ALICE, _amount);

//     // Alice Create Order And Executor Execute Order
//     addLiquidity(ALICE, ERC20(address(wbtc)), _amount, executionOrderFee, initialPriceFeedDatas, true);
//     liquidityTester.assertLiquidityInfo(
//       LiquidityTester.LiquidityExpectedData({
//         token: address(wbtc),
//         who: ALICE,
//         lpTotalSupply: 99_70 ether,
//         totalAmount: _amount,
//         plpLiquidity: 49_850_000,
//         plpAmount: 9_970 ether, //
//         fee: 150_000, //fee = 0.5e8( 0.5e8 -0.3%) = 0.0015 * 1e8
//         executionFee: _totalExecutionOrderFee
//       })
//     );

//     vm.deal(ALICE, executionOrderFee);
//     uint256 _balanceAll = plpV2.balanceOf(ALICE);

//     removeLiquidity(ALICE, address(wbtc), _balanceAll, executionOrderFee, new bytes[](0), false);

//     // setup for remove liquidity feed only 1 token
//     skip(10);
//     bytes32[] memory _newAssetIds = new bytes32[](1);
//     int64[] memory _prices = new int64[](1);
//     uint64[] memory _conf = new uint64[](1);
//     _newAssetIds[0] = wbtcAssetId;
//     _prices[0] = 21_000 * 1e8;
//     _conf[0] = 2;

//     bytes[] memory _newPrices = setPrices(_newAssetIds, _prices, _conf);

//     executePLPOrder(liquidityHandler.nextExecutionOrderIndex(), _newPrices);

//     _totalExecutionOrderFee += (executionOrderFee - 1);
//     liquidityTester.assertLiquidityInfo(
//       LiquidityTester.LiquidityExpectedData({
//         token: address(wbtc),
//         who: ALICE,
//         lpTotalSupply: 0,
//         totalAmount: 429_160,
//         plpLiquidity: 0,
//         plpAmount: 0,
//         fee: 429_160, //150_000 +279_160
//         executionFee: _totalExecutionOrderFee
//       })
//     );
//   }
// }
