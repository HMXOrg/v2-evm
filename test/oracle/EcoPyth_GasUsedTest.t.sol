// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_GasUsedTest is EcoPyth_BaseTest {
  uint128[] internal _updateDatas;
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

    ecoPyth.setUpdater(ALICE, true);
  }

  function testGasUsage_WhenFeed50Prices() external {
    vm.prank(ALICE);
    ecoPyth.updatePriceFeeds(_updateDatas, _encodedVaas);
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
