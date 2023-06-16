// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract MarketTester is StdAssertions {
  struct AssertData {
    uint256 marketIndex;
    uint256 longPositionSize;
    uint256 shortPositionSize;
  }

  IPerpStorage perpStorage;

  constructor(IPerpStorage _perpStorage) {
    perpStorage = _perpStorage;
  }

  function assertMarket(AssertData memory data) external {
    assertEq(perpStorage.getMarketByIndex(data.marketIndex).longPositionSize, data.longPositionSize);
    assertEq(perpStorage.getMarketByIndex(data.marketIndex).shortPositionSize, data.shortPositionSize);
  }
}
