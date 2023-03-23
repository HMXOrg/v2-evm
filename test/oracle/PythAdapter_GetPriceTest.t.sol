// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PythAdapter_BaseTest } from "./PythAdapter_BaseTest.t.sol";
import { PythAdapter } from "@hmx/oracle/PythAdapter.sol";
import { console2 } from "forge-std/console2.sol";

contract PythAdapter_GetPriceTest is PythAdapter_BaseTest {
  function setUp() public override {
    super.setUp();

    pythAdapter.setConfig(wethAssetId, wethPriceId, false);
    pythAdapter.setConfig(wbtcAssetId, wbtcPriceId, false);
    pythAdapter.setConfig(jpyAssetId, jpyPriceId, true);
  }

  function updateWbtcWithConf(uint64 conf) private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = _createPriceFeedUpdateData(
      wbtcPriceId,
      20_000 * 1e8,
      conf,
      -8,
      20_000 * 1e8,
      conf,
      uint64(block.timestamp)
    );

    leanPyth.updatePriceFeeds{ value: leanPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
  }

  function updateWbtcWithBadParam() private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = _createPriceFeedUpdateData(
      wbtcPriceId,
      -20_000 * 1e8,
      0,
      8,
      -20_000 * 1e8,
      0,
      uint64(block.timestamp)
    );

    leanPyth.updatePriceFeeds{ value: leanPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
  }

  function updateJpyWithConf(uint64 conf) private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = _createPriceFeedUpdateData(
      jpyPriceId,
      136.123 * 1e3,
      conf,
      -3,
      136.123 * 1e3,
      conf,
      uint64(block.timestamp)
    );

    leanPyth.updatePriceFeeds{ value: leanPyth.getUpdateFee(priceDataBytes) }(priceDataBytes);
  }

  function testRevert_GetWithUnregisteredAssetId() external {
    vm.expectRevert(abi.encodeWithSignature("PythAdapter_UnknownAssetId()"));
    pythAdapter.getLatestPrice(bytes32(uint256(168)), true, 1e6);
  }

  function testRevert_GetBeforeUpdate() external {
    vm.expectRevert(abi.encodeWithSignature("LeanPyth_PriceFeedNotFound()"));
    pythAdapter.getLatestPrice(wethAssetId, true, 1e6);
  }

  function testRevert_GetWhenPriceIsBad() external {
    updateWbtcWithBadParam();
    vm.expectRevert(abi.encodeWithSignature("PythAdapter_BrokenPythPrice()"));
    pythAdapter.getLatestPrice(wbtcAssetId, true, 1e6);
  }

  function testCorrectness_GetWhenNoConf() external {
    updateWbtcWithConf(0);

    (uint256 maxPrice, , uint256 lastUpdate) = pythAdapter.getLatestPrice(wbtcAssetId, true, 1e6);
    (uint256 minPrice, , ) = pythAdapter.getLatestPrice(wbtcAssetId, false, 1e6);
    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));
  }

  function testRevert_GetWithTooLowConfidenceThreshold() external {
    vm.warp(uint64(block.timestamp + 1));
    // Feed with +-5% conf
    updateWbtcWithConf(1_000 * 1e8);

    vm.expectRevert(abi.encodeWithSignature("PythAdapter_ConfidenceRatioTooHigh()"));
    // But get price with 4% conf threshold, should revert as the conf 5% is unacceptable
    pythAdapter.getLatestPrice(
      wbtcAssetId,
      true,
      0.04 * 1e6 // accept up to 4% conf
    );
  }

  function testCorrecteness_GetWithHighEnoughConfidenceThreshold() external {
    vm.warp(uint64(block.timestamp + 1));
    // Feed with +-5% conf
    updateWbtcWithConf(1_000 * 1e8);

    // And get price with 6% conf threshold
    (uint256 maxPrice, , ) = pythAdapter.getLatestPrice(
      wbtcAssetId,
      true,
      0.06 * 1e6 // 6% conf
    );
    (uint256 minPrice, , ) = pythAdapter.getLatestPrice(
      wbtcAssetId,
      false,
      0.051 * 1e6 // 5.1% conf
    );

    // Should get price successfully
    // And also, min vs max should be unequal
    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
  }

  function testCorrectness_GetInverseQuotePriceWithNoConf() external {
    updateJpyWithConf(0);

    // USD/JPY => 136.123
    // So, JPY/USD should be 1/136.123 ~= 0.00734629...
    (uint256 maxPrice, , uint256 lastUpdate) = pythAdapter.getLatestPrice(jpyAssetId, true, 1e6);
    (uint256 minPrice, , ) = pythAdapter.getLatestPrice(jpyAssetId, false, 1e6);
    assertEq(maxPrice, 0.007346297098947275625720855402 * 1e30);
    assertEq(minPrice, 0.007346297098947275625720855402 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));
  }

  function testCorrectness_GetInverseQuotePriceWithConf() external {
    // Feed with +-10% conf
    updateJpyWithConf(13.612 * 1e3);

    // USD/JPY => 136.123
    // after inversion => 1/136.123 = 0.0073463
    (uint256 maxPrice, , uint256 lastUpdate) = pythAdapter.getLatestPrice(jpyAssetId, true, 1e6);
    (uint256 minPrice, , ) = pythAdapter.getLatestPrice(jpyAssetId, false, 1e6);
    assertEq(maxPrice, 0.007346297098947275625720855402 * 1e30, "Max price");
    assertEq(minPrice, 0.007346297098947275625720855402 * 1e30, "Min price");
    assertEq(lastUpdate, uint64(block.timestamp), "Timestamp");
  }
}
