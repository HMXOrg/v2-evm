// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CIXPythAdapter_BaseTest } from "./CIXPythAdapter_BaseTest.t.sol";
import { CIXPythAdapter } from "@hmx/oracles/CIXPythAdapter.sol";
import { console2 } from "forge-std/console2.sol";

contract CIXPythAdapter_GetPriceTest is CIXPythAdapter_BaseTest {
  function setUp() public override {
    super.setUp();

    // Just init price to make the sanity check pass
    updatePrice(eurPriceId, 1e8);
    updatePrice(jpyPriceId, 1e8);
    updatePrice(gbpPriceId, 1e8);
    updatePrice(cadPriceId, 1e8);
    updatePrice(sekPriceId, 1e8);
    updatePrice(chfPriceId, 1e8);
    vm.warp(2);

    /* 
      EURUSD	55.00%
      USDJPY	15.00%
      GBPUSD	12.50%
      USDCAD	10.00%
      USDSEK	4.00%
      USDCHF	3.50%

      C = 43.92050844
    */

    bytes32[] memory _pythPriceIds = new bytes32[](6);
    _pythPriceIds[0] = eurPriceId;
    _pythPriceIds[1] = jpyPriceId;
    _pythPriceIds[2] = gbpPriceId;
    _pythPriceIds[3] = cadPriceId;
    _pythPriceIds[4] = sekPriceId;
    _pythPriceIds[5] = chfPriceId;

    uint256[] memory _weightsE8 = new uint256[](6);
    _weightsE8[0] = 0.55e8;
    _weightsE8[1] = 0.15e8;
    _weightsE8[2] = 0.125e8;
    _weightsE8[3] = 0.10e8;
    _weightsE8[4] = 0.04e8;
    _weightsE8[5] = 0.035e8;

    bool[] memory _usdQuoteds = new bool[](6);
    _usdQuoteds[0] = true;
    _usdQuoteds[1] = false;
    _usdQuoteds[2] = true;
    _usdQuoteds[3] = false;
    _usdQuoteds[4] = false;
    _usdQuoteds[5] = false;

    cixPythAdapter.setConfig(cix1AssetId, 43.92050844e8, _pythPriceIds, _weightsE8, _usdQuoteds);
  }

  function updatePrice(bytes32 priceId, int64 priceE8) private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = mockPyth.createPriceFeedUpdateData(
      priceId,
      priceE8,
      0,
      -8,
      priceE8,
      0,
      uint64(block.timestamp)
    );

    mockPyth.updatePriceFeeds{ value: mockPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
  }

  function testRevert_GetWithUnregisteredAssetId() external {
    vm.expectRevert(abi.encodeWithSignature("CIXPythAdapter_UnknownAssetId()"));
    cixPythAdapter.getLatestPrice(bytes32(uint256(168)), true, 0);
  }

  function testCorrectness_GetLatestPrice_PriceShouldBeCorrect() external {
    /*
      EURUSD 1.05048
      USDJPY 149.39
      GBPUSD 1.2142
      USDCAD 1.349
      USDSEK 11.06
      USDCHF 0.92
    */
    updatePrice(eurPriceId, 1.05048e8);
    updatePrice(jpyPriceId, 149.39e8);
    updatePrice(gbpPriceId, 1.2142e8);
    updatePrice(cadPriceId, 1.349e8);
    updatePrice(sekPriceId, 11.06e8);
    updatePrice(chfPriceId, 0.92e8);

    (uint256 _price30, ) = cixPythAdapter.getLatestPrice(cix1AssetId, true, 0);

    // Assert with a very small precision error
    assertApproxEqRel(_price30, 100e30, 0.00000001e18, "Price E30 should be 100 USD");
  }

  function testCorrectness_GetLatestPrice_PriceShouldBeCorrect2() external {
    /*
      EURUSD 1.05048
      USDJPY 149.39
      GBPUSD 1.2142
      USDCAD 1.349
      USDSEK 11.06
      USDCHF 0.92
    */
    updatePrice(eurPriceId, 1.05048e8);
    updatePrice(jpyPriceId, 180.00e8);
    updatePrice(gbpPriceId, 1.2142e8);
    updatePrice(cadPriceId, 1.349e8);
    updatePrice(sekPriceId, 11.06e8);
    updatePrice(chfPriceId, 0.92e8);

    (uint256 _price30, ) = cixPythAdapter.getLatestPrice(cix1AssetId, true, 0);

    // Assert with a very small precision error
    assertApproxEqRel(_price30, 102.8354012e30, 0.00000001e18, "Price E30 should be 100 USD");
  }

  function testCorrectness_GetLatestPrice_PublishTimeShouldBeCorrect() external {
    /*
      EURUSD 1.05048
      USDJPY 149.39
      GBPUSD 1.2142
      USDCAD 1.349
      USDSEK 11.06
      USDCHF 0.92
    */

    // Set price with time skip
    vm.warp(100);
    updatePrice(eurPriceId, 1.05048e8);
    vm.warp(200);
    updatePrice(jpyPriceId, 149.39e8);
    vm.warp(300);
    updatePrice(gbpPriceId, 1.2142e8);
    vm.warp(400);
    updatePrice(cadPriceId, 1.349e8);
    vm.warp(500);
    updatePrice(sekPriceId, 11.06e8);
    vm.warp(600);
    updatePrice(chfPriceId, 0.92e8);
    vm.warp(700);

    (uint256 _price30, uint256 _publishTime) = cixPythAdapter.getLatestPrice(cix1AssetId, true, 0);

    // Assert with a very small precision error
    assertApproxEqRel(_price30, 100e30, 0.00000001e18, "Price E30 should be 100 USD");
    assertEq(_publishTime, 100, "Publish time should be the minimum from one of the asset");
  }
}
