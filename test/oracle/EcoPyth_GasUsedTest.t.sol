// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { EcoPyth_BaseTest } from "./EcoPyth_BaseTest.t.sol";
import { EcoPyth, IEcoPythPriceInfo } from "@hmx/oracle/EcoPyth.sol";
import { console2 } from "forge-std/console2.sol";

contract EcoPyth_GasUsedTest is EcoPyth_BaseTest {
  bytes32[] internal _priceIds;
  uint128[] internal _packedPriceDatas;
  bytes32 internal _encodedVaas;

  function setUp() public override {
    super.setUp();

    _priceIds = new bytes32[](50);
    _packedPriceDatas = new uint128[](50);
    for (uint i = 0; i < 50; i++) {
      _priceIds[i] = bytes32(uint256(i));
      _packedPriceDatas[i] = uint128(i);
    }
    _encodedVaas = keccak256("someEncodedVaas");

    ecoPyth.setUpdater(ALICE, true);
  }

  function testGasUsage_WhenFeed50Prices() external {
    vm.prank(ALICE);
    ecoPyth.updatePriceFeeds(_priceIds, _packedPriceDatas, _encodedVaas);
  }
}
