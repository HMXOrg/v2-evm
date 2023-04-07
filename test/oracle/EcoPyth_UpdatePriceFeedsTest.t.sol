// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo, PythStructs } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_UpdatePriceFeedsTest is EcoPyth_BaseTest {
  function setUp() public override {
    super.setUp();

    ecoPyth.insertAsset("1");
    ecoPyth.insertAsset("2");
    ecoPyth.insertAsset("3");
    ecoPyth.insertAsset("4");
  }

  function testRevert_OnlyUpdater() external {
    int24[] memory _prices = new int24[](1);
    _prices[0] = int24(-1);
    bytes32[] memory updateDatas = ecoPyth.buildUpdateData(_prices);
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("EcoPyth_OnlyUpdater()"));
    ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
  }

  function testCorrectness_WhenUpdatePriceFeeds() external {
    {
      int24[] memory _prices = new int24[](4);
      _prices[0] = int24(-99);
      _prices[1] = int24(3127);
      _prices[2] = int24(98527);
      _prices[3] = int24(-887272);
      bytes32[] memory updateDatas = ecoPyth.buildUpdateData(_prices);
      ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
      PythStructs.Price memory _priceInfo = ecoPyth.getPriceUnsafe("1");

      assertEq(_priceInfo.publishTime, 1);
      assertEq(_priceInfo.price, int64(99014933)); // 0.99014933 * 1e8

      _priceInfo = ecoPyth.getPriceUnsafe("2");
      assertEq(_priceInfo.price, int64(136708996)); // 1.36708996 * 1e8

      _priceInfo = ecoPyth.getPriceUnsafe("3");
      assertEq(_priceInfo.price, int64(1900025000000)); // 19000.25 * 1e8
    }
  }

  // function testCorrectness_WhenUpdatePriceFeedWithEmptyArray() external {
  //   {
  //     uint128[] memory updateDatas = new uint128[](0);
  //     ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
  //     uint112 packedPriceInfo = ecoPyth.packedPriceInfos(4);
  //     IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
  //     assertEq(_priceInfo.publishTime, 0);
  //     assertEq(_priceInfo.price, 0);
  //   }
  // }

  // function testCorrectness_WhenUpdatePriceFeedsWithWrongPublishTime() external {
  //   {
  //     uint128[] memory updateDatas = new uint128[](1);
  //     updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(11111), int64(2222222));
  //     ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
  //     uint112 packedPriceInfo = ecoPyth.packedPriceInfos(4);
  //     IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
  //     assertEq(_priceInfo.publishTime, uint64(11111));
  //     assertEq(_priceInfo.price, int64(2222222));

  //     updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(2), int64(3333333));
  //     packedPriceInfo = ecoPyth.packedPriceInfos(4);
  //     _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
  //     assertEq(_priceInfo.publishTime, uint64(11111));
  //     assertEq(_priceInfo.price, int64(2222222));
  //   }
  // }
}
