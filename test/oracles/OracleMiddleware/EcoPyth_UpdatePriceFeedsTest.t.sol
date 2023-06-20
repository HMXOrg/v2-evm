// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo, PythStructs } from "@hmx/oracles/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_UpdatePriceFeedsTest is EcoPyth_BaseTest {
  function setUp() public override {
    super.setUp();

    ecoPyth.insertAssetId("1");
    ecoPyth.insertAssetId("2");
    ecoPyth.insertAssetId("3");
    ecoPyth.insertAssetId("4");
    ecoPyth.insertAssetId("5");
    ecoPyth.insertAssetId("6");
    ecoPyth.insertAssetId("7");
    ecoPyth.insertAssetId("8");
    ecoPyth.insertAssetId("9");
    ecoPyth.insertAssetId("10");
    ecoPyth.insertAssetId("11");
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
      int24[] memory _prices = new int24[](12);
      _prices[0] = int24(-99);
      _prices[1] = int24(3127);
      _prices[2] = int24(98527);
      _prices[3] = int24(0);
      _prices[4] = int24(1);
      _prices[5] = int24(2);
      _prices[6] = int24(3);
      _prices[7] = int24(4);
      _prices[8] = int24(5);
      _prices[9] = int24(6);
      _prices[10] = int24(7);
      _prices[11] = int24(8);
      bytes32[] memory priceUpdateDatas = ecoPyth.buildPriceUpdateData(_prices);
      uint24[] memory _publishTime = new uint24[](12);
      _publishTime[0] = uint24(0);
      _publishTime[1] = uint24(1);
      _publishTime[2] = uint24(2);
      _publishTime[3] = uint24(3);
      _publishTime[4] = uint24(4);
      _publishTime[5] = uint24(5);
      _publishTime[6] = uint24(6);
      _publishTime[7] = uint24(7);
      _publishTime[8] = uint24(8);
      _publishTime[9] = uint24(9);
      _publishTime[10] = uint24(10);
      _publishTime[11] = uint24(11);
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

      _priceInfo = ecoPyth.getPriceUnsafe("5");
      assertEq(_priceInfo.price, int64(1.0001 * 1e8)); // 1.0001
      assertEq(_priceInfo.publishTime, 1604);

      _priceInfo = ecoPyth.getPriceUnsafe("6");
      assertEq(_priceInfo.price, int64(1.00020001 * 1e8)); // 1.00020001
      assertEq(_priceInfo.publishTime, 1605);

      _priceInfo = ecoPyth.getPriceUnsafe("7");
      assertEq(_priceInfo.price, int64(1.00030003 * 1e8)); // 1.000300030001
      assertEq(_priceInfo.publishTime, 1606);

      _priceInfo = ecoPyth.getPriceUnsafe("8");
      assertEq(_priceInfo.price, int64(1.00040006 * 1e8)); // 1.0004000600040001
      assertEq(_priceInfo.publishTime, 1607);

      _priceInfo = ecoPyth.getPriceUnsafe("9");
      assertEq(_priceInfo.price, int64(1.00050010 * 1e8)); // 1.00050010001000050001
      assertEq(_priceInfo.publishTime, 1608);

      _priceInfo = ecoPyth.getPriceUnsafe("10");
      assertEq(_priceInfo.price, int64(1.00060015 * 1e8)); // 1.000600150020001500060001
      assertEq(_priceInfo.publishTime, 1609);

      _priceInfo = ecoPyth.getPriceUnsafe("11");
      assertEq(_priceInfo.price, int64(1.00070021 * 1e8)); // 1.0007002100350035002100070001
      assertEq(_priceInfo.publishTime, 1610);
    }
  }
}
