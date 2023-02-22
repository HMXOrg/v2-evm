// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

import { AddressUtils } from "../../../src/libraries/AddressUtils.sol";

contract TradeService_GetNextBorrowingRate is TradeService_Base {
  using AddressUtils for address;

  function setUp() public virtual override {
    super.setUp();
  }

  function test_getNextBorrowingRate() external {
    // TVL
    // 1000000 USDT -> 1000000 USD
    mockCalculator.setPLPValue(1_000_000 * 1e30);
    // ALICE add collateral
    // 10000 USDT -> free collateral -> 10000 USD
    mockCalculator.setFreeCollateral(10_000 * 1e30);

    // ETH price 1600 USD
    {
      uint256 price = 0.1 * 1e30;
      mockOracle.setPrice(address(weth).toBytes32(), price);
    }
    // BTC price 1600 USD
    {
      uint256 price = 0.2 * 1e30;
      mockOracle.setPrice(address(wbtc).toBytes32(), price);
    }

    {
      vm.warp(100);
      int256 sizeDelta = 1_000_000 * 1e30;
      address subAccount = getSubAccount(ALICE, 0);
      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

      vaultStorage.setTraderBalance(subAccount, address(weth), 1e18);
      vaultStorage.setTraderBalance(subAccount, address(wbtc), 5e8);

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);

      vm.warp(101);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
      // tradeService.updateBorrowingRate(0);

      IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
      // 0.0001 * 90000 / 1000000 = 0.000009
      assertEq(_globalAssetClass.sumBorrowingRate, 0.000009 * 1e18, "sumBorrowingRate");
      assertEq(_globalAssetClass.lastBorrowingTime, 101);

      // 0.000009 * 90000 = 0.81
      assertEq(perpStorage.getSubAccountFee(subAccount), 0);

      assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
      assertEq(vaultStorage.traderBalances(subAccount, address(wbtc)), 1.45 * 1e8);

      // 1 * 15% = 0.15
      assertEq(vaultStorage.devFees(address(weth)), 0.15 * 1e18);
      // 5 - 1.45 = 3.55 * 15% = 0.5325
      assertEq(vaultStorage.devFees(address(wbtc)), 0.5325 * 1e8);

      vm.warp(102);
      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
      // tradeService.decreasePosition(ALICE, 0, ethMarketIndex, 2_000_000 * 1e30);

      // 0.000018 * 180000 = 3.24 - 0.29 = 2.95
      assertEq(perpStorage.getSubAccountFee(subAccount), 2.95 * 1e30);

      // assertEq(vaultStorage.traderBalances(subAccount, address(weth)), 0);
      // assertEq(vaultStorage.traderBalances(subAccount, address(wbtc)), 1.45 * 1e8);

      // // 1 * 15% = 0.15
      // assertEq(vaultStorage.devFees(address(weth)), 0.15 * 1e18);
      // // 5 - 1.45 = 3.55 * 15% = 0.5325
      // assertEq(vaultStorage.devFees(address(wbtc)), 0.5325 * 1e8);
    }
  }
}
