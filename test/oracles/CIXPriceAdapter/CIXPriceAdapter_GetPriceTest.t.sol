// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CIXPriceAdapter_BaseTest } from "./CIXPriceAdapter_BaseTest.t.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { console2 } from "forge-std/console2.sol";

contract CIXPriceAdapter_GetPriceTest is CIXPriceAdapter_BaseTest {
  function setUp() public override {
    super.setUp();

    /* 
      EURUSD	55.00%
      USDJPY	15.00%
      GBPUSD	12.50%
      USDCAD	10.00%
      USDSEK	4.00%
      USDCHF	3.50%

      C = 43.92050844
    */

    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = eurAssetId;
    _assetIds[1] = jpyAssetId;
    _assetIds[2] = gbpAssetId;
    _assetIds[3] = cadAssetId;
    _assetIds[4] = sekAssetId;
    _assetIds[5] = chfAssetId;

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

    uint256 _c = 43.92050844e8;

    cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
  }

  function testRevert_GetPrice_WhenNotAllPriceRelatedSubmitted() external {
    // Set price, but without JPY
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas = new IEcoPythCalldataBuilder3.BuildData[](5);
    _buildDatas[0].assetId = eurAssetId;
    _buildDatas[0].priceE8 = 1.05048e8;

    _buildDatas[1].assetId = chfAssetId;
    _buildDatas[1].priceE8 = 0.92e8;

    _buildDatas[2].assetId = cadAssetId;
    _buildDatas[2].priceE8 = 1.349e8;

    _buildDatas[3].assetId = gbpAssetId;
    _buildDatas[3].priceE8 = 1.2142e8;

    _buildDatas[4].assetId = sekAssetId;
    _buildDatas[4].priceE8 = 11.06e8;

    vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_MissingPriceFromBuildData()"));
    uint256 _priceE18 = cixPriceAdapter.getPrice(_buildDatas);
  }

  function testCorrectness_GetPrice_PriceShouldBeCorrect() external {
    /*
      EURUSD 1.05048
      USDJPY 149.39
      GBPUSD 1.2142
      USDCAD 1.349
      USDSEK 11.06
      USDCHF 0.92
    */

    // Set price along with unreleated asset
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas = new IEcoPythCalldataBuilder3.BuildData[](10);
    _buildDatas[0].assetId = eurAssetId;
    _buildDatas[0].priceE8 = 1.05048e8;

    _buildDatas[1].assetId = "UNKNOWN1";
    _buildDatas[1].priceE8 = 1.1e8;

    _buildDatas[2].assetId = "UNKNOWN2";
    _buildDatas[2].priceE8 = 2.2e8;

    _buildDatas[3].assetId = chfAssetId;
    _buildDatas[3].priceE8 = 0.92e8;

    _buildDatas[4].assetId = cadAssetId;
    _buildDatas[4].priceE8 = 1.349e8;

    _buildDatas[5].assetId = "UNKNOWN3";
    _buildDatas[5].priceE8 = 3.3e8;

    _buildDatas[6].assetId = jpyAssetId;
    _buildDatas[6].priceE8 = 149.39e8;

    _buildDatas[7].assetId = "UNKNOWN4";
    _buildDatas[7].priceE8 = 4.4e8;

    _buildDatas[8].assetId = gbpAssetId;
    _buildDatas[8].priceE8 = 1.2142e8;

    _buildDatas[9].assetId = sekAssetId;
    _buildDatas[9].priceE8 = 11.06e8;

    uint256 _priceE18 = cixPriceAdapter.getPrice(_buildDatas);

    // Assert with a very small precision error
    assertApproxEqRel(_priceE18, 100e18, 0.00000001e18, "Price E18 should be 100 USD");
  }

  function testCorrectness_GetPrice_PriceShouldBeCorrect2() external {
    /*
      EURUSD 1.05048
      USDJPY 180.0
      GBPUSD 1.2142
      USDCAD 1.349
      USDSEK 11.06
      USDCHF 0.92
    */

    // Set price along with unreleated asset
    IEcoPythCalldataBuilder3.BuildData[] memory _buildDatas = new IEcoPythCalldataBuilder3.BuildData[](10);
    _buildDatas[0].assetId = eurAssetId;
    _buildDatas[0].priceE8 = 1.05048e8;

    _buildDatas[1].assetId = "UNKNOWN1";
    _buildDatas[1].priceE8 = 1.1e8;

    _buildDatas[2].assetId = "UNKNOWN2";
    _buildDatas[2].priceE8 = 2.2e8;

    _buildDatas[3].assetId = chfAssetId;
    _buildDatas[3].priceE8 = 0.92e8;

    _buildDatas[4].assetId = cadAssetId;
    _buildDatas[4].priceE8 = 1.349e8;

    _buildDatas[5].assetId = "UNKNOWN3";
    _buildDatas[5].priceE8 = 3.3e8;

    _buildDatas[6].assetId = jpyAssetId;
    _buildDatas[6].priceE8 = 180.00e8;

    _buildDatas[7].assetId = "UNKNOWN4";
    _buildDatas[7].priceE8 = 4.4e8;

    _buildDatas[8].assetId = gbpAssetId;
    _buildDatas[8].priceE8 = 1.2142e8;

    _buildDatas[9].assetId = sekAssetId;
    _buildDatas[9].priceE8 = 11.06e8;

    uint256 _priceE18 = cixPriceAdapter.getPrice(_buildDatas);

    // Assert with a very small precision error
    assertApproxEqRel(_priceE18, 102.8354012e18, 0.00000001e18, "Price E18 should be 102.83 USD");
  }
}
