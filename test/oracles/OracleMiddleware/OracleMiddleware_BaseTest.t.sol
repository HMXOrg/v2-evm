// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";

contract OracleMiddleware_BaseTest is BaseTest {
  function setUp() public virtual {
    vm.deal(ALICE, 1 ether);

    // Feed wbtc
    {
      pythAdapter.setConfig(wbtcAssetId, wbtcPriceId, false);

      bytes[] memory priceDataBytes = new bytes[](1);
      priceDataBytes[0] = mockPyth.createPriceFeedUpdateData(
        wbtcPriceId,
        20_000 * 1e8,
        500 * 1e8,
        -8,
        20_000 * 1e8,
        500 * 1e8,
        uint64(block.timestamp)
      );

      vm.startPrank(ALICE);
      mockPyth.updatePriceFeeds{ value: mockPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
      vm.stopPrank();
    }
  }
}
