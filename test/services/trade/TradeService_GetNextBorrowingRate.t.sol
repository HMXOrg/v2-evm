// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { TradeService_Base } from "./TradeService_Base.t.sol";

import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

contract TradeService_GetNextBorrowingRate is TradeService_Base {
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
    uint256 price = 1_600 * 1e30;
    mockOracle.setPrice(price);

    vm.warp(100);
    {
      int256 sizeDelta = 1_000_000 * 1e30;

      bytes32 _positionId = getPositionId(ALICE, 0, ethMarketIndex);

      tradeService.increasePosition(ALICE, 0, ethMarketIndex, sizeDelta);
    }

    vm.warp(101);
    tradeService.updateBorrowingRate(0);

    IPerpStorage.GlobalAssetClass memory _globalAssetClass = perpStorage.getGlobalAssetClassByIndex(0);
    // 0.0001 * 90000 / 1000000 = 0.000009
    assertEq(_globalAssetClass.sumBorrowingRate, 0.000009 * 1e18);
    assertEq(_globalAssetClass.lastBorrowingTime, 101);
  }
}
