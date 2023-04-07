// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_GasUsedTest is EcoPyth_BaseTest {
  uint128[] internal _updateDatas;
  bytes32[] internal _prices;
  bytes32 internal _encodedVaas;

  function setUp() public override {
    super.setUp();

    uint256 _size = 50;
    _updateDatas = new uint128[](_size);

    for (uint i = 0; i < _size; i++) {
      ecoPyth.insertAsset(bytes32(type(uint256).max - i));
      uint128 _data = ecoPyth.buildUpdateData(
        uint16(i) + 1,
        type(uint48).max / 256 - uint48(i),
        type(int64).max / 256 - int64(uint64(i))
      );
      _updateDatas[i] = _data;
    }
    _encodedVaas = keccak256("someEncodedVaas");

    _prices = new bytes32[](5);
    _prices[0] = bytes32(
      abi.encodePacked(
        int24(-1),
        int24(2),
        int24(3),
        int24(4),
        int24(5),
        int24(6),
        int24(7),
        int24(8),
        int24(9),
        int24(10)
      )
    );
    _prices[1] = bytes32(
      abi.encodePacked(
        int24(11),
        int24(12),
        int24(13),
        int24(14),
        int24(15),
        int24(16),
        int24(17),
        int24(18),
        int24(19),
        int24(20)
      )
    );
    _prices[2] = bytes32(
      abi.encodePacked(
        int24(21),
        int24(22),
        int24(23),
        int24(24),
        int24(25),
        int24(26),
        int24(27),
        int24(28),
        int24(29),
        int24(30)
      )
    );
    _prices[3] = bytes32(
      abi.encodePacked(
        int24(31),
        int24(32),
        int24(33),
        int24(34),
        int24(35),
        int24(36),
        int24(37),
        int24(38),
        int24(39),
        int24(40)
      )
    );
    _prices[4] = bytes32(
      abi.encodePacked(
        int24(41),
        int24(42),
        int24(43),
        int24(44),
        int24(45),
        int24(46),
        int24(47),
        int24(48),
        int24(49),
        int24(50)
      )
    );

    ecoPyth.setUpdater(ALICE, true);
  }

  function testGasUsage_WhenFeed50Prices() external {
    vm.prank(ALICE);
    ecoPyth.updatePriceFeeds(_prices, _encodedVaas);

    for (uint i = 0; i < 50; i++) {
      ecoPyth.getPriceUnsafe(bytes32(type(uint256).max - i));
    }
  }
}

// contract EcoPyth_GasUsedTest2 is EcoPyth_BaseTest {
//   mapping(bytes32 => uint128) a;
//   uint128[1] internal b;

//   function setUp() public override {
//     super.setUp();

//     a[bytes32(uint256(1))] = uint128(100);
//     b[0] = 1;
//   }

//   function testGasUsage_A() external {
//     a[bytes32(uint256(1))] = uint128(200);
//   }

//   function testGasUsage_B() external {
//     b[0] = uint128(200);
//   }

//   function testGasUsage_C() external {
//     uint112 a = uint112(12345);
//   }

//   function testGasUsage_D() external {
//     uint256 a = (12345);
//   }

//   function testGasUsage_E() external {
//     uint256 a = uint256(12345);
//   }
// }
