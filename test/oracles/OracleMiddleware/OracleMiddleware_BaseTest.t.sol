// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";

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

    // Link oracle middleware to wbtc and weth oracle adapter
    bytes32[] memory marketIds = new bytes32[](2);
    marketIds[0] = wbtcAssetId;
    marketIds[1] = wethAssetId;

    IOracleAdapter[] memory adapters = new IOracleAdapter[](2);
    adapters[0] = pythAdapter;
    adapters[1] = pythAdapter;

    oracleMiddleware.setOracleAdapters(marketIds, adapters);
    oracleMiddleware.setOracleAdapters(marketIds, adapters);
  }
}
