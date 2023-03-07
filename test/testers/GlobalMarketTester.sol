// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract GlobalMarketTester is StdAssertions {
  struct AssertData {
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 longOpenInterest;
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    uint256 shortOpenInterest;
  }

  PerpStorage perpStorage;

  constructor(PerpStorage _perpStorage) {
    perpStorage = _perpStorage;
  }

  function assertGlobalMarket(uint256 _marketIndex, AssertData memory _data) external {
    IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_globalMarket.longPositionSize, _data.longPositionSize);
    assertEq(_globalMarket.longAvgPrice, _data.longAvgPrice);
    assertEq(_globalMarket.longOpenInterest, _data.longOpenInterest);
    assertEq(_globalMarket.shortPositionSize, _data.shortPositionSize);
    assertEq(_globalMarket.shortAvgPrice, _data.shortAvgPrice);
    assertEq(_globalMarket.shortOpenInterest, _data.shortOpenInterest);
  }
}
