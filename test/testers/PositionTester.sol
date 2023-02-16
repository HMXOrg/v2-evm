// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { PerpStorage } from "../../src/storages/PerpStorage.sol";
import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

import { MockOracleMiddleware } from "../mocks/MockOracleMiddleware.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract PositionTester is StdAssertions {
  struct DecreaePositionAssertionData {
    uint256 sizeDelta;
    uint256 avgPriceDelta;
    uint256 reserveValueDelta;
  }

  PerpStorage perpStorage;
  MockOracleMiddleware oracle;

  bytes32 cachePositionId;
  IPerpStorage.Position cachePosition;
  IPerpStorage.GlobalMarket cacheMarketGlobal;

  constructor(PerpStorage _perpStorage, MockOracleMiddleware _oracle) {
    perpStorage = _perpStorage;
    oracle = _oracle;
  }

  function watch(bytes32 _positionId) external {
    // todo: this can access state directly
    cachePositionId = _positionId;
    cachePosition = perpStorage.getPositionById(_positionId);
    cacheMarketGlobal = perpStorage.getGlobalMarketByIndex(
      cachePosition.marketIndex
    );
  }

  // assert cache position with current position from storage
  function assertDecreasePositionResult(
    DecreaePositionAssertionData memory _data
  ) external {
    // assert position state
    IPerpStorage.Position memory _currentPosition = perpStorage.getPositionById(
      cachePositionId
    );
    int256 _sizeDelta = cachePosition.positionSizeE30 -
      _currentPosition.positionSizeE30;

    assertEq(
      uint256(_sizeDelta > 0 ? _sizeDelta : -_sizeDelta),
      _data.sizeDelta
    );
    assertEq(
      cachePosition.avgEntryPriceE30 - _currentPosition.avgEntryPriceE30,
      _data.avgPriceDelta
    );
    assertEq(
      cachePosition.reserveValueE30 - _currentPosition.reserveValueE30,
      _data.reserveValueDelta
    );

    // assert market global
    IPerpStorage.GlobalMarket memory _currentMarketGlobal = perpStorage
      .getGlobalMarketByIndex(_currentPosition.marketIndex);

    // long position
    if (cachePosition.positionSizeE30 > 0) {
      // LONG position
      assertEq(
        cacheMarketGlobal.longPositionSize -
          _currentMarketGlobal.longPositionSize,
        _data.sizeDelta
      );
      // todo: support when has logic to recalculate average price
      // assertEq(cacheMarketGlobal.longAvgPrice - _currentMarketGlobal.longAvgPrice, 0);
      // todo: support on funding rate calculation story
      // assertEq(cacheMarketGlobal.longFundingRate - _currentMarketGlobal.longFundingRate, 0);
      assertEq(
        cacheMarketGlobal.longOpenInterest -
          _currentMarketGlobal.longOpenInterest,
        (_data.sizeDelta * 1e30) / oracle.priceE30()
      );
    } else {
      assertEq(
        cacheMarketGlobal.shortPositionSize -
          _currentMarketGlobal.shortPositionSize,
        _data.sizeDelta
      );
      // todo: support when has logic to recalculate average price
      // assertEq(cacheMarketGlobal.shortAvgPrice - _currentMarketGlobal.shortAvgPrice, 0);
      // todo: support on funding rate calculation story
      // assertEq(cacheMarketGlobal.shortFundingRate - _currentMarketGlobal.shortFundingRate, 0);
      assertEq(
        cacheMarketGlobal.shortOpenInterest -
          _currentMarketGlobal.shortOpenInterest,
        (_data.sizeDelta * 1e30) / oracle.priceE30()
      );
    }

    // todo: support on funding rate calculation story
    // assertEq(_currentMarketGlobal.lastFundingTime, block.timestamp);
  }
}
