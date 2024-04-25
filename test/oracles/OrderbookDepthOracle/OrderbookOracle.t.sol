// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { OrderbookOracle } from "@hmx/oracles/OrderbookOracle.sol";

contract OrderbookOracle_Test is BaseTest {
  uint256 constant MAX_DIFF = 0.00001 ether;
  OrderbookOracle internal orderbookOracle;

  function setUp() public virtual {
    orderbookOracle = new OrderbookOracle();

    orderbookOracle.setUpdater(address(this), true);

    orderbookOracle.insertMarketIndex(0);
    orderbookOracle.insertMarketIndex(1);
    orderbookOracle.insertMarketIndex(2);
    orderbookOracle.insertMarketIndex(3);
    orderbookOracle.insertMarketIndex(4);
    orderbookOracle.insertMarketIndex(5);
    orderbookOracle.insertMarketIndex(6);
    orderbookOracle.insertMarketIndex(7);
    orderbookOracle.insertMarketIndex(8);
    orderbookOracle.insertMarketIndex(9);
    orderbookOracle.insertMarketIndex(10);
    orderbookOracle.insertMarketIndex(11);
    orderbookOracle.insertMarketIndex(13);
  }

  function testCorrectness_updateDepths() external {
    int24[] memory askDepthTicks = new int24[](13);
    askDepthTicks[0] = 149149;
    askDepthTicks[1] = 149150;
    askDepthTicks[2] = 149151;
    askDepthTicks[3] = 149152;
    askDepthTicks[4] = 149153;
    askDepthTicks[5] = 149154;
    askDepthTicks[6] = 149155;
    askDepthTicks[7] = 149156;
    askDepthTicks[8] = 149157;
    askDepthTicks[9] = 218230;
    askDepthTicks[10] = 149159;
    askDepthTicks[11] = 149160;
    askDepthTicks[12] = 149161;

    int24[] memory bidDepthTicks = new int24[](13);
    bidDepthTicks[0] = 149149;
    bidDepthTicks[1] = 149150;
    bidDepthTicks[2] = 149151;
    bidDepthTicks[3] = 149152;
    bidDepthTicks[4] = 149153;
    bidDepthTicks[5] = 149154;
    bidDepthTicks[6] = 149155;
    bidDepthTicks[7] = 149156;
    bidDepthTicks[8] = 149157;
    bidDepthTicks[9] = 218230;
    bidDepthTicks[10] = 149159;
    bidDepthTicks[11] = 149160;
    bidDepthTicks[12] = 149161;

    int24[] memory coeffVariantTicks = new int24[](13);
    coeffVariantTicks[0] = -60708;
    coeffVariantTicks[1] = -60709;
    coeffVariantTicks[2] = -60710;
    coeffVariantTicks[3] = -60711;
    coeffVariantTicks[4] = -60712;
    coeffVariantTicks[5] = -60713;
    coeffVariantTicks[6] = -60714;
    coeffVariantTicks[7] = -60715;
    coeffVariantTicks[8] = -60716;
    coeffVariantTicks[9] = -60717;
    coeffVariantTicks[10] = -60718;
    coeffVariantTicks[11] = -60719;
    coeffVariantTicks[12] = -60720;

    bytes32[] memory askDepths = orderbookOracle.buildUpdateData(askDepthTicks);
    bytes32[] memory bidDepths = orderbookOracle.buildUpdateData(bidDepthTicks);
    bytes32[] memory coeffVariants = orderbookOracle.buildUpdateData(coeffVariantTicks);
    orderbookOracle.updateData(askDepths, bidDepths, coeffVariants);

    (uint256 askDepth, uint256 bidDepth, uint256 coeffVariant) = orderbookOracle.getData(0);
    assertApproxEqRel(askDepth, 3000094.37572017 * 1e8, MAX_DIFF);
    assertApproxEqRel(bidDepth, 3000094.37572017 * 1e8, MAX_DIFF);
    assertApproxEqRel(coeffVariant, 0.00231 * 1e8, MAX_DIFF);

    (askDepth, bidDepth, coeffVariant) = orderbookOracle.getData(1);
    assertApproxEqRel(askDepth, 3000394.38515774 * 1e8, MAX_DIFF);
    assertApproxEqRel(bidDepth, 3000394.38515774 * 1e8, MAX_DIFF);
    assertApproxEqRel(coeffVariant, 0.0023098 * 1e8, MAX_DIFF);

    (askDepth, bidDepth, coeffVariant) = orderbookOracle.getData(9);
    assertApproxEqRel(askDepth, 3000092392.7855706 * 1e8, MAX_DIFF);
    assertApproxEqRel(bidDepth, 3000092392.7855706 * 1e8, MAX_DIFF);
    assertApproxEqRel(coeffVariant, 0.00230795 * 1e8, MAX_DIFF);

    (askDepth, bidDepth, coeffVariant) = orderbookOracle.getData(13);
    assertApproxEqRel(askDepth, 3003696.46969349 * 1e8, MAX_DIFF);
    assertApproxEqRel(bidDepth, 3003696.46969349 * 1e8, MAX_DIFF);
    assertApproxEqRel(coeffVariant, 0.00230726 * 1e8, MAX_DIFF);
  }
}
