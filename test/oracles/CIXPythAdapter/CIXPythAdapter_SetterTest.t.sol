// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { CIXPythAdapter_BaseTest } from "./CIXPythAdapter_BaseTest.t.sol";
import { CIXPythAdapter } from "@hmx/oracles/CIXPythAdapter.sol";
import { ICIXPythAdapter } from "@hmx/oracles/interfaces/ICIXPythAdapter.sol";
import { console2 } from "forge-std/console2.sol";

contract CIXPythAdapter_SetterTest is CIXPythAdapter_BaseTest {
  function setUp() public override {
    super.setUp();

    // Just init price to make the sanity check pass
    updatePrice(eurPriceId, 1e8);
    updatePrice(jpyPriceId, 1e8);
    updatePrice(gbpPriceId, 1e8);
    updatePrice(cadPriceId, 1e8);
    updatePrice(sekPriceId, 1e8);
    updatePrice(chfPriceId, 1e8);
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

  function testCorrectness_WhenSetConfig() external {
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

    uint256 _c = 43.92050844e8;

    // Expect no revert
    cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);

    ICIXPythAdapter.CIXPythPriceConfig memory _config = cixPythAdapter.getConfigByAssetId(cix1AssetId);
    assertEq(_config.cE8, _c);
    for (uint256 i; i < 6; i++) {
      assertEq(_config.pythPriceIds[i], _pythPriceIds[i]);
      assertEq(_config.weightsE8[i], _weightsE8[i]);
      assertEq(_config.usdQuoteds[i], _usdQuoteds[i]);
    }
  }

  function testRevert_WhenSetConfig_WithNonOwner() external {
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

    uint256 _c = 43.92050844e8;

    // Revert if not owner
    vm.expectRevert("Ownable: caller is not the owner");
    vm.startPrank(address(ALICE));
    cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
    vm.stopPrank();
  }

  function testRevert_WhenSetConfig_WithBadWeight() external {
    bytes32[] memory _pythPriceIds = new bytes32[](6);
    _pythPriceIds[0] = eurPriceId;
    _pythPriceIds[1] = jpyPriceId;
    _pythPriceIds[2] = gbpPriceId;
    _pythPriceIds[3] = cadPriceId;
    _pythPriceIds[4] = sekPriceId;
    _pythPriceIds[5] = chfPriceId;

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

    // Revert if not owner
    vm.expectRevert(abi.encodeWithSignature("CIXPythAdapter_BadWeightSum()"));
    cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
  }

  function testRevert_WhenSetConfig_WithBadParams() external {
    bytes32[] memory _pythPriceIds = new bytes32[](6);
    _pythPriceIds[0] = eurPriceId;
    _pythPriceIds[1] = jpyPriceId;
    _pythPriceIds[2] = gbpPriceId;
    _pythPriceIds[3] = cadPriceId;
    _pythPriceIds[4] = sekPriceId;
    _pythPriceIds[5] = chfPriceId;

    // Bad weight length
    {
      uint256[] memory _weightsE8 = new uint256[](5);
      bool[] memory _usdQuoteds = new bool[](6);
      uint256 _c = 43.92050844e8;
      vm.expectRevert(abi.encodeWithSignature("CIXPythAdapter_BadParams()"));
      cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
    }

    // Bad usdQuoteds length
    {
      uint256[] memory _weightsE8 = new uint256[](6);
      bool[] memory _usdQuoteds = new bool[](7);
      uint256 _c = 43.92050844e8;
      vm.expectRevert(abi.encodeWithSignature("CIXPythAdapter_BadParams()"));
      cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
    }

    // Bad c value
    {
      uint256[] memory _weightsE8 = new uint256[](6);
      bool[] memory _usdQuoteds = new bool[](6);
      uint256 _c = 0;
      vm.expectRevert(abi.encodeWithSignature("CIXPythAdapter_BadParams()"));
      cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
    }
  }

  function testRevert_WhenSetConfig_WithBadPriceId() external {
    bytes32[] memory _pythPriceIds = new bytes32[](6);
    _pythPriceIds[0] = eurPriceId;
    _pythPriceIds[1] = jpyPriceId;
    _pythPriceIds[2] = gbpPriceId;
    _pythPriceIds[3] = cadPriceId;
    _pythPriceIds[4] = sekPriceId;
    _pythPriceIds[5] = "unknown_price_id";

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

    // Revert when doing sanity check
    vm.expectRevert(abi.encodeWithSignature("PriceFeedNotFound()"));
    cixPythAdapter.setConfig(cix1AssetId, _c, _pythPriceIds, _weightsE8, _usdQuoteds);
  }
}
