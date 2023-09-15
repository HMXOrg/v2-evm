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
  function testCorrectness_SmokeTest_liquidate() external {
    (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceData(1);
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();
    address[] memory liqSubAccounts = new address[](10);

    // NOTE: MUST ignore when it's address(0), filtering is needed.
    liqSubAccounts = liquidationReader.getLiquidatableSubAccount(10, 0, assetIds, prices, shouldInverts);

    vm.startPrank(POS_MANAGER);
    botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < 10; i++) {
      if (liqSubAccounts[i] == address(0)) continue;
      botHandler.liquidate(
        liqSubAccounts[i],
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );
      // Liquidated, no pos left.
      assertEq(perpStorage.getNumberOfSubAccountPosition(liqSubAccounts[i]), 0);
    }
    botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }
}
