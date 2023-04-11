// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_GasUsedTest is EcoPyth_BaseTest {
  int24[] internal _prices;
  uint24[] internal _publishTimeDiff;
  bytes32[] internal _updateDataPrice;
  bytes32[] internal _updateDataPublishTime;
  bytes32 internal _encodedVaas;

  function setUp() public override {
    super.setUp();

    uint256 _size = 50;
    _prices = new int24[](50);
    _publishTimeDiff = new uint24[](50);

    for (uint i = 0; i < _size; i++) {
      ecoPyth.insertPriceId(bytes32(type(uint256).max - i));
      _prices[i] = int24(int256(i));
      _publishTimeDiff[i] = uint24(i);
    }
    _encodedVaas = keccak256("someEncodedVaas");

    ecoPyth.setUpdater(ALICE, true);
  }

  function testGasUsage_WhenFeed50Prices() external {
    _updateDataPrice = ecoPyth.buildPriceUpdateData(_prices);
    _updateDataPublishTime = ecoPyth.buildPublishTimeUpdateData(_publishTimeDiff);
    vm.prank(ALICE);
    ecoPyth.updatePriceFeeds(_updateDataPrice, _updateDataPublishTime, 1600, _encodedVaas);

    for (uint i = 0; i < _prices.length; i++) {
      ecoPyth.getPriceUnsafe(bytes32(type(uint256).max - i));
    }
  }
}
