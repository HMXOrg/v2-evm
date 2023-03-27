// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_WithActions } from "@hmx-test/integration/99_BaseIntTest_WithActions.i.sol";

import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";

contract TC09 is BaseIntTest_WithActions {
  function testCorrectness_TC09() external {
    bytes[] memory priceData = new bytes[](0);

    // T0: Initialized state
    {
      //deal with out of gas
      vm.deal(ALICE, 10 ether);
      vm.deal(BOB, 10 ether);

      usdt.mint(ALICE, 100_000 * 1e6);
      wbtc.mint(ALICE, 0.5 * 1e8);

      wbtc.mint(BOB, 10 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    {
      // BOB add liquidity
      addLiquidity(BOB, wbtc, 10 * 1e8, executionOrderFee, priceData, true);
    }

    vm.warp(block.timestamp + 1);
    {
      // Alice deposits 10,000(USD) of WBTC
      depositCollateral(ALICE, 0, wbtc, 0.05 * 1e8);
      depositCollateral(ALICE, 1, wbtc, 0.05 * 1e8);
    }

    vm.warp(block.timestamp + 1);
    // T1: Alice buy long JPYUSD 100,000 USD at 0.008 USD
    {
      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 20_000 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      // buy
      marketBuy(ALICE, 0, jpyMarketIndex, 100_000 * 1e30, address(wbtc), priceData);
      marketBuy(ALICE, 1, wbtcMarketIndex, 10_000 * 1e30, address(wbtc), priceData);
    }

    // T2: Alice buy the position for 20 mins, JPYUSD dumped hard to 0.007945967421533571712355979340 USD. This makes Alice account went below her kill level
    vm.warp(block.timestamp + (20 * MINUTES));
    {
      uint256 protocolFeesBefore = vaultStorage.protocolFees(address(wbtc));
      uint256 devFeesBefore = vaultStorage.devFees(address(wbtc));

      bytes32[] memory _assetIds = new bytes32[](3);
      _assetIds[0] = jpyAssetId;
      _assetIds[1] = usdcAssetId;
      _assetIds[2] = wbtcAssetId;
      int64[] memory _prices = new int64[](3);
      _prices[0] = 125.85 * 1e3;
      _prices[1] = 1 * 1e8;
      _prices[2] = 20_000 * 1e8;
      uint64[] memory _confs = new uint64[](3);
      _confs[0] = 0;
      _confs[1] = 0;
      _confs[2] = 0;
      setPrices(_assetIds, _prices, _confs);

      liquidate(getSubAccount(ALICE, 0), priceData);
      /*
       *
       * |       loss        | trading |      borrowing     |     funding    | liquidation | unit |
       * |-------------------|---------|--------------------|----------------|-------------|------|
       * | 675.4072308303536 |      30 | 1.4623871614844526 | 15.99999999996 |           5 |  USD |
       * |        0.03377036 |  0.0015 |         0.00007311 |     0.00079999 |     0.00025 |  BTC |
       *
       * total pay: 0.03377036 + 0.0015 + 0.00007311 + 0.00079999 + 0.00025 = 0.03639346
       * trader balance = 0.04850000 - 0.03639346 = 0.01210654
       * dev fee = (0.0015 * 15%) + (0.00007311 * 15%) = 0.00023596
       * plp liquidity = 9.97 + (0.03377036 + (0.00007311 - 0.00001096)) = 10.00383251
       * protocol fee = 0.0015 - (0.0015 * 15%) = 0.001275
       * liquidation fee = 0.00025
       */
      address aliceSubAccount1 = getSubAccount(ALICE, 0);
      assertSubAccountTokenBalance(ALICE, address(wbtc), true, 0.01210654 * 1e8);
      assertVaultsFees(
        address(wbtc),
        protocolFeesBefore + (0.001275 * 1e8),
        devFeesBefore + (0.00023596 * 1e8),
        0.00079999 * 1e8
      );
      assertPLPLiquidity(address(wbtc), 10.00383251 * 1e8);
      assertSubAccountTokenBalance(BOT, address(wbtc), true, 0.00025 * 1e8);
      assertNumberOfPosition(aliceSubAccount1, 0);
      assertPositionInfoOf(aliceSubAccount1, jpyMarketIndex, 0, 0, 0, 0, 0, 0);
      assertMarketLongPosition(jpyMarketIndex, 0, 0);
    }
    {
      vm.expectRevert(abi.encodeWithSignature("ILiquidationService_AccountHealthy()"));
      liquidate(getSubAccount(ALICE, 1), priceData);

      address aliceSubAccount2 = getSubAccount(ALICE, 1);
      assertNumberOfPosition(aliceSubAccount2, 1);
    }
  }
}
