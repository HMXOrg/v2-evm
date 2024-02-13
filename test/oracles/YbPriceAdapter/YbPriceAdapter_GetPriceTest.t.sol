// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { YbPriceAdapter_BaseTest } from "@hmx-test/oracles/YbPriceAdapter/YbPriceAdapter_BaseTest.t.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract YbPriceAdapter_GetPriceTest is YbPriceAdapter_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenGetPriceFromBuildData() external {
    IEcoPythCalldataBuilder3.BuildData[] memory buildDatas = new IEcoPythCalldataBuilder3.BuildData[](1);
    buildDatas[0] = IEcoPythCalldataBuilder3.BuildData({
      assetId: wethAssetId,
      priceE8: 2_500 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 0
    });

    uint256 priceE18 = ybPriceAdapter.getPrice(buildDatas);
    assertEq(priceE18, 2_500 * 1e18);

    // Assuming ybETH grows 10% from yield
    dealyb(payable(address(ybeth)), address(this), 10 ether);
    weth.setNextYield(1 ether);

    // ybETH price should be 10% higher
    priceE18 = ybPriceAdapter.getPrice(buildDatas);
    assertEq(priceE18, 2_750 * 1e18);
  }

  function testCorrectness_WhenGetPriceFromRawPriceE8() external {
    uint256[] memory priceE8s = new uint256[](1);
    priceE8s[0] = 2_500 * 1e8;

    uint256 priceE18 = ybPriceAdapter.getPrice(priceE8s);
    assertEq(priceE18, 2_500 * 1e18);

    // Assuming ybETH grows 10% from yield
    dealyb(payable(address(ybeth)), address(this), 10 ether);
    weth.setNextYield(1 ether);

    // ybETH price should be 10% higher
    priceE18 = ybPriceAdapter.getPrice(priceE8s);
    assertEq(priceE18, 2_750 * 1e18);
  }
}
