// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CIXPriceAdapter_BaseTest } from "./CIXPriceAdapter_BaseTest.t.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";
import { ICIXPriceAdapter } from "@hmx/oracles/interfaces/ICIXPriceAdapter.sol";
import { console2 } from "forge-std/console2.sol";

contract CIXPriceAdapter_SetterTest is CIXPriceAdapter_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenSetConfig() external {
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

    // Expect no revert
    cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
    // uint a = cixPriceAdapter.getConfig();
    ICIXPriceAdapter.CIXConfig memory _config = cixPriceAdapter.getConfig();

    assertEq(_config.cE8, _c);
    for (uint256 i; i < 6; i++) {
      assertEq(_config.assetIds[i], _assetIds[i]);
      assertEq(_config.weightsE8[i], _weightsE8[i]);
      assertEq(_config.usdQuoteds[i], _usdQuoteds[i]);
    }
  }

  function testRevert_WhenSetConfig_WithNonOwner() external {
    bytes32[] memory _assetIds = new bytes32[](0);
    uint256[] memory _weightsE8 = new uint256[](0);
    bool[] memory _usdQuoteds = new bool[](0);
    uint256 _c = 1;

    // Revert if not owner
    vm.expectRevert("Ownable: caller is not the owner");
    vm.startPrank(address(ALICE));
    cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
    vm.stopPrank();
  }

  function testRevert_WhenSetConfig_WithBadWeight() external {
    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = eurAssetId;
    _assetIds[1] = jpyAssetId;
    _assetIds[2] = gbpAssetId;
    _assetIds[3] = cadAssetId;
    _assetIds[4] = sekAssetId;
    _assetIds[5] = chfAssetId;
    // Total weight != 100%
    uint256[] memory _weightsE8 = new uint256[](6);
    _weightsE8[0] = 0.1e8;
    _weightsE8[1] = 0.1e8;
    _weightsE8[2] = 0.1e8;
    _weightsE8[3] = 0.1e8;
    _weightsE8[4] = 0.1e8;
    _weightsE8[5] = 0.1e8;
    bool[] memory _usdQuoteds = new bool[](6);
    _usdQuoteds[0] = true;
    _usdQuoteds[1] = false;
    _usdQuoteds[2] = true;
    _usdQuoteds[3] = false;
    _usdQuoteds[4] = false;
    _usdQuoteds[5] = false;
    uint256 _c = 43.92050844e8;

    vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_BadWeightSum()"));
    cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
  }

  function testRevert_WhenSetConfig_WithBadParams() external {
    bytes32[] memory _assetIds = new bytes32[](6);
    _assetIds[0] = eurAssetId;
    _assetIds[1] = jpyAssetId;
    _assetIds[2] = gbpAssetId;
    _assetIds[3] = cadAssetId;
    _assetIds[4] = sekAssetId;
    _assetIds[5] = chfAssetId;
    // Bad weight length
    {
      uint256[] memory _weightsE8 = new uint256[](5);
      bool[] memory _usdQuoteds = new bool[](6);
      uint256 _c = 43.92050844e8;
      vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_BadParams()"));
      cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
    }
    // Bad usdQuoteds length
    {
      uint256[] memory _weightsE8 = new uint256[](6);
      bool[] memory _usdQuoteds = new bool[](7);
      uint256 _c = 43.92050844e8;
      vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_BadParams()"));
      cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
    }
    // Bad c value
    {
      uint256[] memory _weightsE8 = new uint256[](6);
      bool[] memory _usdQuoteds = new bool[](6);
      uint256 _c = 0;
      vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_BadParams()"));
      cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);
    }
  }

  function testRevert_WhenSetConfig_WithDeviatedC() external {
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

    // 1. Set config normally, should be ok at this point
    cixPriceAdapter.setConfig(_c, _assetIds, _weightsE8, _usdQuoteds);

    // 2. Try set config with very skew c, should revert
    uint256 _skewedC = 48.92050844e8;
    vm.expectRevert(abi.encodeWithSignature("CIXPriceAdapter_COverDiff()"));
    cixPriceAdapter.setConfig(_skewedC, _assetIds, _weightsE8, _usdQuoteds);
  }
}
