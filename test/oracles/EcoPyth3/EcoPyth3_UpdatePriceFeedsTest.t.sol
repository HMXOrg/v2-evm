// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { EcoPyth3_BaseTest, console2 } from "@hmx-test/oracles/EcoPyth3/EcoPyth3_BaseTest.t.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

contract EcoPyth3_UpdatePriceFeedTest is EcoPyth3_BaseTest {
  function setUp() public override {
    super.setUp();
    for (uint i = 0; i < 18; i++) {
      ecoPyth3.insertAssetId(bytes32(i));
    }
  }

  function testCorrectess_WhenPriceFeedUpdated() external {
    uint256[] memory _priceE18s = new uint256[](20);
    _priceE18s[0] = 2400 * 1e18;
    _priceE18s[1] = 42_949_672.95 * 1e18;
    _priceE18s[2] = 2400 * 1e18;
    _priceE18s[3] = 2400 * 1e18;
    _priceE18s[4] = 2400 * 1e18;
    _priceE18s[5] = 2400 * 1e18;
    _priceE18s[6] = 2400 * 1e18;
    _priceE18s[7] = 2400 * 1e18;
    _priceE18s[8] = 2400 * 1e18;
    _priceE18s[9] = 2400 * 1e18;
    _priceE18s[10] = 3200 * 1e18;
    _priceE18s[11] = 3300 * 1e18;
    _priceE18s[12] = 3400 * 1e18;
    _priceE18s[13] = 3500 * 1e18;
    _priceE18s[14] = 3600 * 1e18;
    _priceE18s[15] = 3700 * 1e18;
    _priceE18s[16] = 3800 * 1e18;
    _priceE18s[17] = 3900 * 1e18;
    _priceE18s[18] = 4000 * 1e18;
    _priceE18s[19] = 4100 * 1e18;

    uint24[] memory _publishTimeDiff = new uint24[](20);
    _publishTimeDiff[0] = 100;
    _publishTimeDiff[1] = 200;
    _publishTimeDiff[2] = 300;
    _publishTimeDiff[3] = 400;
    _publishTimeDiff[4] = 500;
    _publishTimeDiff[5] = 600;
    _publishTimeDiff[6] = 700;
    _publishTimeDiff[7] = 800;
    _publishTimeDiff[8] = 900;
    _publishTimeDiff[9] = 1000;
    _publishTimeDiff[10] = 1100;
    _publishTimeDiff[11] = 1200;
    _publishTimeDiff[12] = 1300;
    _publishTimeDiff[13] = 1400;
    _publishTimeDiff[14] = 1500;
    _publishTimeDiff[15] = 1600;
    _publishTimeDiff[16] = 1700;
    _publishTimeDiff[17] = 1800;
    _publishTimeDiff[18] = 1900;
    _publishTimeDiff[19] = 2000;

    bytes32[] memory _updateData = ecoPyth3.buildPriceUpdateData(_priceE18s);
    bytes32[] memory _timeUpdateData = ecoPyth3.buildPublishTimeUpdateData(_publishTimeDiff);

    ecoPyth3.updatePriceFeeds(_updateData, _timeUpdateData, block.timestamp, bytes32(0));

    PythStructs.Price memory price = ecoPyth3.getPriceUnsafe("ETH");
    PythStructs.Price memory price2 = ecoPyth3.getPriceUnsafe("BTC");
    PythStructs.Price memory price3 = ecoPyth3.getPriceUnsafe(bytes32(0));
    PythStructs.Price memory price4 = ecoPyth3.getPriceUnsafe(bytes32(uint256(15)));
    PythStructs.Price memory price5 = ecoPyth3.getPriceUnsafe(bytes32(uint256(1)));

    assertEq(price.price, 239996839126);
    assertEq(price2.price, 4294967295000000);
    assertEq(price3.price, 239996839126);
    assertEq(price4.price, 389982349172);
    assertEq(price5.price, 239996839126);
  }
}
