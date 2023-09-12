// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";

import "forge-std/console.sol";

contract Smoke_Liquidate is Smoke_Base {
  address[] internal activeSubAccounts;

  function setUp() public virtual override {
    super.setUp();
  }

  // for shorter time
  function testCorrectness_smoke_liquidateFirstTen() external {
    (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceData();
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();
    address[] memory liqSubAccounts = new address[](10);

    // NOTE: MUST ignore when it's address(0), filtering is needed.
    liqSubAccounts = liquidationReader.getLiquidatableSubAccount(10, 0, assetIds, prices, shouldInverts);

    vm.startPrank(POS_MANAGER);
    for (uint i = 0; i < 10; i++) {
      if (liqSubAccounts[i] == address(0)) continue;
      botHandler.updateLiquidityEnabled(false);
      botHandler.liquidate(
        liqSubAccounts[i],
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );
      botHandler.updateLiquidityEnabled(true);
      // Liquidated, no pos left.
      assertEq(perpStorage.getNumberOfSubAccountPosition(liqSubAccounts[i]), 0);
    }
    vm.stopPrank();
  }

  // prank as real use-case, NOTE: take a FK long time
  function testCorrectness_smoke_liquidateAsAPI() external {
    activeSubAccounts = perpStorage.getActiveSubAccounts(10_000, 0);
    console.log("accounts:", activeSubAccounts.length);
    (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceData();
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();
    address[] memory liqSubAccounts = new address[](10);

    // Liquidate 10 accounts per chunk, length / 10, + 1 for rounding up
    for (uint chunk = 0; chunk < (activeSubAccounts.length / 10) + 1; chunk++) {
      console.log("Chunk:", chunk);
      // NOTE: MUST ignore when it's address(0), filtering is needed.
      liqSubAccounts = liquidationReader.getLiquidatableSubAccount(10, 0, assetIds, prices, shouldInverts);

      vm.startPrank(POS_MANAGER);
      for (uint i = 0; i < 10; i++) {
        if (liqSubAccounts[i] == address(0)) continue;
        botHandler.updateLiquidityEnabled(false);
        botHandler.liquidate(
          liqSubAccounts[i],
          priceUpdateData,
          publishTimeUpdateData,
          block.timestamp,
          keccak256("someEncodedVaas")
        );
        botHandler.updateLiquidityEnabled(true);
        // Liquidated, no pos left.
        assertEq(perpStorage.getNumberOfSubAccountPosition(liqSubAccounts[i]), 0);
      }
    }
    vm.stopPrank();
  }

  function _setPriceData()
    internal
    view
    returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts)
  {
    bytes32[] memory pythRes = ecoPyth.getAssetIds();
    uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    assetIds = new bytes32[](len - 1);
    prices = new uint64[](len - 1);
    shouldInverts = new bool[](len - 1);

    for (uint i = 1; i < len; i++) {
      assetIds[i - 1] = pythRes[i];
      prices[i - 1] = 1 * 1e8;
      if (i == 4) {
        shouldInverts[i - 1] = true; // JPY
      } else {
        shouldInverts[i - 1] = false;
      }
    }
  }
}
