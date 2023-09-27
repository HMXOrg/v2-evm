// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { OrderbookDepthOracle } from "@hmx/oracles/OrderbookDepthOracle.sol";

contract OrderbookDepthOracle_Test is BaseTest {
  uint256 constant MAX_DIFF = 0.0000000001 ether;
  OrderbookDepthOracle internal orderbookDepthOracle;

  function setUp() public virtual {
    orderbookDepthOracle = new OrderbookDepthOracle();

    orderbookDepthOracle.setUpdater(address(this), true);

    orderbookDepthOracle.insertMarketIndex(0);
    orderbookDepthOracle.insertMarketIndex(1);
    orderbookDepthOracle.insertMarketIndex(2);
    orderbookDepthOracle.insertMarketIndex(3);
    orderbookDepthOracle.insertMarketIndex(4);
    orderbookDepthOracle.insertMarketIndex(5);
    orderbookDepthOracle.insertMarketIndex(6);
    orderbookDepthOracle.insertMarketIndex(7);
    orderbookDepthOracle.insertMarketIndex(8);
    orderbookDepthOracle.insertMarketIndex(9);
    orderbookDepthOracle.insertMarketIndex(10);
    orderbookDepthOracle.insertMarketIndex(11);
    orderbookDepthOracle.insertMarketIndex(13);
  }

  function testCorrectness_updateDepths() external {
    int24[] memory depthTicks = new int24[](13);
    depthTicks[0] = 149149;
    depthTicks[1] = 149150;
    depthTicks[2] = 149151;
    depthTicks[3] = 149152;
    depthTicks[4] = 149153;
    depthTicks[5] = 149154;
    depthTicks[6] = 149155;
    depthTicks[7] = 149156;
    depthTicks[8] = 149157;
    depthTicks[9] = 218230;
    depthTicks[10] = 149159;
    depthTicks[11] = 149160;
    depthTicks[12] = 149161;

    bytes32[] memory _updateData = orderbookDepthOracle.buildPriceUpdateData(depthTicks);
    orderbookDepthOracle.updateDepths(_updateData);

    assertApproxEqRel(orderbookDepthOracle.getDepth(0), 3000094.37572017 * 1e8, MAX_DIFF);
    assertApproxEqRel(orderbookDepthOracle.getDepth(1), 3000394.38515774 * 1e8, MAX_DIFF);
    assertApproxEqRel(orderbookDepthOracle.getDepth(11), 3003396.13008048 * 1e8, MAX_DIFF);
    assertApproxEqRel(orderbookDepthOracle.getDepth(9), 3000092392.7855706 * 1e8, MAX_DIFF);
  }
}
