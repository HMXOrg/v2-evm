// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract MarketTester is StdAssertions {
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

  function assertMarket(uint256 _marketIndex, AssertData memory _data) external {
    IPerpStorage.Market memory _market = perpStorage.getMarketByIndex(_marketIndex);

    assertEq(_market.longPositionSize, _data.longPositionSize);
    assertEq(_market.longAvgPrice, _data.longAvgPrice);
    assertEq(_market.shortPositionSize, _data.shortPositionSize);
    assertEq(_market.shortAvgPrice, _data.shortAvgPrice);
  }
}
