// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_ParsePriceInfoTest is EcoPyth_BaseTest {
  function testCorrectness_WhenParsePriceInfo() external {
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(uint64(0), int32(0), int64(0), uint64(0));
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, uint64(0));
      assertEq(_priceInfo.expo, int32(0));
      assertEq(_priceInfo.price, int64(0));
      assertEq(_priceInfo.conf, uint64(0));
    }
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(uint64(1), int32(1), int64(1), uint64(1));
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, uint64(1));
      assertEq(_priceInfo.expo, int32(1));
      assertEq(_priceInfo.price, int64(1));
      assertEq(_priceInfo.conf, uint64(1));
    }
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(uint64(1), int32(-1), int64(-1), uint64(1));
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, uint64(1));
      assertEq(_priceInfo.expo, int32(-1));
      assertEq(_priceInfo.price, int64(-1));
      assertEq(_priceInfo.conf, uint64(1));
    }
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(
        type(uint64).max,
        type(int32).max,
        type(int64).max,
        type(uint64).max
      );
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, type(uint64).max);
      assertEq(_priceInfo.expo, type(int32).max);
      assertEq(_priceInfo.price, type(int64).max);
      assertEq(_priceInfo.conf, type(uint64).max);
    }
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(
        type(uint64).min,
        type(int32).min,
        type(int64).min,
        type(uint64).min
      );
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, type(uint64).min);
      assertEq(_priceInfo.expo, type(int32).min);
      assertEq(_priceInfo.price, type(int64).min);
      assertEq(_priceInfo.conf, type(uint64).min);
    }
    {
      uint256 _packedPriceData = ecoPyth.buildPackedPriceData(uint64(55), int32(-88), int64(73), uint64(33));
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePriceInfo(_packedPriceData);
      assertEq(_priceInfo.publishTime, uint64(55));
      assertEq(_priceInfo.expo, int32(-88));
      assertEq(_priceInfo.price, int64(73));
      assertEq(_priceInfo.conf, uint64(33));
    }
  }
}
