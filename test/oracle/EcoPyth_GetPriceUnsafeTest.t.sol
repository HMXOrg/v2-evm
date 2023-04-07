// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo, PythStructs } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_UpdatePriceFeedsTest is EcoPyth_BaseTest {
  function testCorrectness_WhenGetPriceUnsafe() external {
    {
      uint128[] memory updateDatas = new uint128[](1);
      updateDatas[0] = ecoPyth.buildUpdateData(uint16(1), uint48(11111), int64(2222222));
      ecoPyth.updatePriceFeeds(updateDatas, keccak256("pyth"));
      PythStructs.Price memory _priceInfo = ecoPyth.getPriceUnsafe("ETH");
      assertEq(_priceInfo.publishTime, uint64(11111));
      assertEq(_priceInfo.price, int64(2222222));
    }
  }
}
