// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IOracleAdapter } from "../../base/BaseTest.sol";
import { OracleMiddleware } from "../../../src/oracles/OracleMiddleware.sol";
import { AddressUtils } from "../../../src/libraries/AddressUtils.sol";

contract OracleMiddleware_BaseTest is BaseTest {
  using AddressUtils for address;
  OracleMiddleware oracleMiddleware;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();
    oracleMiddleware = deployed.oracleMiddleware;

    vm.deal(ALICE, 1 ether);

    // Feed wbtc
    {
      deployed.pythAdapter.setPythPriceId(address(wbtc).toBytes32(), wbtcPriceId);

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
    marketIds[0] = address(wbtc).toBytes32();
    marketIds[1] = address(weth).toBytes32();

    IOracleAdapter[] memory adapters = new IOracleAdapter[](2);
    adapters[0] = deployed.pythAdapter;
    adapters[1] = deployed.pythAdapter;

    deployed.oracleMiddleware.setOracleAdapters(marketIds, adapters);
    deployed.oracleMiddleware.setOracleAdapters(marketIds, adapters);
  }
}
