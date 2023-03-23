// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract GlobalMarketTester is StdAssertions {
  struct AssertData {
    uint256 longPositionSize;
    uint256 longAvgPrice;
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
  }

  IPerpStorage perpStorage;

  constructor(IPerpStorage _perpStorage) {
    perpStorage = _perpStorage;
  }

  function assertGlobalMarket(uint256 _marketIndex, AssertData memory _data) external {
    IPerpStorage.GlobalMarket memory _globalMarket = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_globalMarket.longPositionSize, _data.longPositionSize);
    assertEq(_globalMarket.longAvgPrice, _data.longAvgPrice);
    assertEq(_globalMarket.shortPositionSize, _data.shortPositionSize);
    assertEq(_globalMarket.shortAvgPrice, _data.shortAvgPrice);
  }
}
