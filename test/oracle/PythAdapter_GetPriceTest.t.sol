// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { PythAdapter_BaseTest } from "./PythAdapter_BaseTest.t.sol";
import { PythAdapter } from "../../src/oracle/PythAdapter.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressUtils } from "../../src/libraries/AddressUtils.sol";

contract PythAdapter_GetPriceTest is PythAdapter_BaseTest {
  using AddressUtils for address;

  function setUp() public override {
    super.setUp();

    // ALICE is updater
    vm.deal(ALICE, 1 ether);
    pythAdapter.setUpdater(ALICE, true);
    pythAdapter.setPythPriceId(address(weth).toBytes32(), wethPriceId);
    pythAdapter.setPythPriceId(address(wbtc).toBytes32(), wbtcPriceId);
  }

  function updateWbtcWithConf(uint64 conf) private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = mockPyth.createPriceFeedUpdateData(
      wbtcPriceId,
      20_000 * 1e8,
      conf,
      -8,
      20_000 * 1e8,
      conf,
      uint64(block.timestamp)
    );

    vm.startPrank(ALICE);
    pythAdapter.updatePrices{ value: pythAdapter.getUpdateFee(priceDataBytes) }(
      priceDataBytes
    );
    vm.stopPrank();
  }

  function updateWbtcWithBadParam() private {
    // Feed only wbtc
    bytes[] memory priceDataBytes = new bytes[](1);
    priceDataBytes[0] = mockPyth.createPriceFeedUpdateData(
      wbtcPriceId,
      -20_000 * 1e8,
      0,
      8,
      -20_000 * 1e8,
      0,
      uint64(block.timestamp)
    );

    vm.startPrank(ALICE);
    pythAdapter.updatePrices{ value: pythAdapter.getUpdateFee(priceDataBytes) }(
      priceDataBytes
    );
    vm.stopPrank();
  }

  function testRevert_GetWithUnregisteredAssetId() external {
    vm.expectRevert(abi.encodeWithSignature("PythAdapter_UnknownAssetId()"));
    pythAdapter.getLatestPrice(bytes32(uint256(168)), true, 1 ether);
  }

  function testRevert_GetBeforeUpdate() external {
    vm.expectRevert(abi.encodeWithSignature("PriceFeedNotFound()"));
    pythAdapter.getLatestPrice(address(weth).toBytes32(), true, 1 ether);
  }

  function testRevert_GetWhenPriceIsBad() external {
    updateWbtcWithBadParam();
    vm.expectRevert(abi.encodeWithSignature("PythAdapter_BrokenPythPrice()"));
    pythAdapter.getLatestPrice(address(wbtc).toBytes32(), true, 1 ether);
  }

  function testCorrectness_GetWhenNoConf() external {
    updateWbtcWithConf(0);

    (uint256 maxPrice, uint256 lastUpdate) = pythAdapter.getLatestPrice(
      address(wbtc).toBytes32(),
      true,
      1 ether
    );
    (uint256 minPrice, ) = pythAdapter.getLatestPrice(
      address(wbtc).toBytes32(),
      false,
      1 ether
    );
    assertEq(maxPrice, 20_000 * 1e30);
    assertEq(minPrice, 20_000 * 1e30);
    assertEq(lastUpdate, uint64(block.timestamp));
  }

  function testRevert_GetWithTooLowConfidenceThreshold() external {
    vm.warp(uint64(block.timestamp + 1));
    // Feed with +-5% conf
    updateWbtcWithConf(1_000 * 1e8);

    vm.expectRevert(
      abi.encodeWithSignature("PythAdapter_ConfidenceRatioTooHigh()")
    );
    // But get price with 4% conf threshold, should revert as the conf 5% is unacceptable
    pythAdapter.getLatestPrice(
      address(wbtc).toBytes32(),
      true,
      0.04 ether // accept up to 4% conf
    );
  }

  function testCorrecteness_GetWithHighEnoughConfidenceThreshold() external {
    vm.warp(uint64(block.timestamp + 1));
    // Feed with +-5% conf
    updateWbtcWithConf(1_000 * 1e8);

    // And get price with 6% conf threshold
    (uint256 maxPrice, ) = pythAdapter.getLatestPrice(
      address(wbtc).toBytes32(),
      true,
      0.06 ether // 6% conf
    );
    (uint256 minPrice, ) = pythAdapter.getLatestPrice(
      address(wbtc).toBytes32(),
      false,
      0.051 ether // 5.1% conf
    );

    // Should get price successfully
    // And also, min vs max should be unequal
    assertEq(maxPrice, 21_000 * 1e30);
    assertEq(minPrice, 19_000 * 1e30);
  }
}
