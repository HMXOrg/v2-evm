// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo, PythStructs } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_UpdatePriceFeedsTest is EcoPyth_BaseTest {
  function setUp() public override {
    super.setUp();

    ecoPyth.insertPriceId("1");
    ecoPyth.insertPriceId("2");
    ecoPyth.insertPriceId("3");
    ecoPyth.insertPriceId("4");
  }

  function testRevert_OnlyUpdater() external {
    int24[] memory _prices = new int24[](1);
    _prices[0] = int24(-1);
    bytes32[] memory priceUpdateDatas = ecoPyth.buildPriceUpdateData(_prices);
    uint24[] memory _publishTimes = new uint24[](1);
    _publishTimes[0] = uint24(1);
    bytes32[] memory publishTimeUpdateDatas = ecoPyth.buildPublishTimeUpdateData(_publishTimes);
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("EcoPyth_OnlyUpdater()"));
    ecoPyth.updatePriceFeeds(priceUpdateDatas, publishTimeUpdateDatas, 0, keccak256("pyth"));
  }

  function testCorrectness_WhenUpdatePriceFeeds() external {
    {
      int24[] memory _prices = new int24[](4);
      _prices[0] = int24(-99);
      _prices[1] = int24(3127);
      _prices[2] = int24(98527);
      _prices[3] = int24(0);
      bytes32[] memory priceUpdateDatas = ecoPyth.buildPriceUpdateData(_prices);
      uint24[] memory _publishTime = new uint24[](4);
      _publishTime[0] = uint24(0);
      _publishTime[1] = uint24(1);
      _publishTime[2] = uint24(2);
      _publishTime[3] = uint24(3);
      bytes32[] memory publishTimeUpdateDatas = ecoPyth.buildPublishTimeUpdateData(_publishTime);
      ecoPyth.updatePriceFeeds(priceUpdateDatas, publishTimeUpdateDatas, 1600, keccak256("pyth"));
      PythStructs.Price memory _priceInfo = ecoPyth.getPriceUnsafe("1");

      assertEq(_priceInfo.price, int64(99014933)); // 0.99014933 * 1e8
      assertEq(_priceInfo.publishTime, 1600);

      _priceInfo = ecoPyth.getPriceUnsafe("2");
      assertEq(_priceInfo.price, int64(136708996)); // 1.36708996 * 1e8
      assertEq(_priceInfo.publishTime, 1601);

      _priceInfo = ecoPyth.getPriceUnsafe("3");
      assertEq(_priceInfo.price, int64(1900024965577)); // 19000.25 * 1e8
      assertEq(_priceInfo.publishTime, 1602);

      _priceInfo = ecoPyth.getPriceUnsafe("4");
      assertEq(_priceInfo.price, int64(1e8)); // 1 * 1e8
      assertEq(_priceInfo.publishTime, 1603);
    }
  }
}
