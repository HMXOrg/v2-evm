// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_ParseFunctionTest is EcoPyth_BaseTest {
  function testCorrectness_WhenParsePackedPriceInfo() external {
    {
      uint112 _data = ecoPyth.buildPackedPriceInfo(uint48(11111), int64(2222222));
      IEcoPythPriceInfo memory _priceInfo = ecoPyth.parsePackedPriceInfo(_data);
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
  }

  function testCorrectness_WhenParseUpdateData() external {
    {
      uint128 _data = ecoPyth.buildUpdateData(uint16(4), uint48(11111), int64(2222222));
      (uint16 _priceIndex, IEcoPythPriceInfo memory _priceInfo) = ecoPyth.parseUpdateData(_data);
      assertEq(_priceIndex, uint16(4));
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
    {
      uint128 _data = ecoPyth.buildUpdateData(type(uint16).max - 1, uint48(11111), int64(2222222));
      (uint16 _priceIndex, IEcoPythPriceInfo memory _priceInfo) = ecoPyth.parseUpdateData(_data);
      assertEq(_priceIndex, type(uint16).max - 1);
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
  }
}
