// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_UpdatePriceFeedsTest is EcoPyth_BaseTest {
  function testRevert_OnlyUpdater() external {
    uint128[] memory updateDatas = new uint128[](1);
    updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(11111), int64(2222222));
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("EcoPyth_OnlyUpdater()"));
    ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
  }

  function testCorrectness_WhenUpdatePriceFeeds() external {
    {
      uint128[] memory updateDatas = new uint128[](1);
      updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(11111), int64(2222222));
      ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
      uint112 packedPriceInfo = ecoPyth.packedPriceInfos(4);
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
  }

  function testCorrectness_WhenUpdatePriceFeedWithEmptyArray() external {
    {
      uint128[] memory updateDatas = new uint128[](0);
      ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
      uint112 packedPriceInfo = ecoPyth.packedPriceInfos(4);
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
      assertEq(_priceInfo.publishTime, 0);
      assertEq(_priceInfo.price, 0);
    }
  }

  function testCorrectness_WhenUpdatePriceFeedsWithWrongPublishTime() external {
    {
      uint128[] memory updateDatas = new uint128[](1);
      updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(11111), int64(2222222));
      ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
      uint112 packedPriceInfo = ecoPyth.packedPriceInfos(4);
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));

      updateDatas[0] = ecoPyth.buildUpdateData(uint16(4), uint48(2), int64(3333333));
      packedPriceInfo = ecoPyth.packedPriceInfos(4);
      _priceInfo = ecoPyth.parsePackedPriceInfo(packedPriceInfo);
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
  }
}
