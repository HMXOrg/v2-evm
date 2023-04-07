// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_GasUsedTest is EcoPyth_BaseTest {
  int24[] internal _prices;
  bytes32[] internal _updateData;
  bytes32 internal _encodedVaas;

  function setUp() public override {
    super.setUp();

    uint256 _size = 50;

    for (uint i = 0; i < _size; i++) {
      ecoPyth.insertAsset(bytes32(type(uint256).max - i));
    }
    _encodedVaas = keccak256("someEncodedVaas");

    _prices = new int24[](50);
    _prices[0] = int24(-1);
    _prices[1] = int24(2);
    _prices[2] = int24(3);
    _prices[3] = int24(4);
    _prices[4] = int24(5);
    _prices[5] = int24(6);
    _prices[6] = int24(7);
    _prices[7] = int24(8);
    _prices[8] = int24(9);
    _prices[9] = int24(10);
    _prices[10] = int24(11);
    _prices[11] = int24(12);
    _prices[12] = int24(13);
    _prices[13] = int24(14);
    _prices[14] = int24(15);
    _prices[15] = int24(16);
    _prices[16] = int24(17);
    _prices[17] = int24(18);
    _prices[18] = int24(19);
    _prices[19] = int24(20);
    _prices[20] = int24(21);
    _prices[21] = int24(22);
    _prices[22] = int24(23);
    _prices[23] = int24(24);
    _prices[24] = int24(25);
    _prices[25] = int24(26);
    _prices[26] = int24(27);
    _prices[27] = int24(28);
    _prices[28] = int24(29);
    _prices[29] = int24(30);
    _prices[30] = int24(31);
    _prices[31] = int24(32);
    _prices[32] = int24(33);
    _prices[33] = int24(34);
    _prices[34] = int24(35);
    _prices[35] = int24(36);
    _prices[36] = int24(37);
    _prices[37] = int24(38);
    _prices[38] = int24(39);
    _prices[39] = int24(40);
    _prices[40] = int24(41);
    _prices[41] = int24(42);
    _prices[42] = int24(43);
    _prices[43] = int24(44);
    _prices[44] = int24(45);
    _prices[45] = int24(46);
    _prices[46] = int24(47);
    _prices[47] = int24(48);
    _prices[48] = int24(49);
    _prices[49] = int24(50);

    ecoPyth.setUpdater(ALICE, true);
  }

  function testGasUsage_WhenFeed50Prices() external {
    _updateData = ecoPyth.buildUpdateData(_prices);
    vm.prank(ALICE);
    ecoPyth.updatePriceFeeds(_updateData, _encodedVaas);

    for (uint i = 0; i < _prices.length; i++) {
      ecoPyth.getPriceUnsafe(bytes32(type(uint256).max - i));
    }
  }
}
