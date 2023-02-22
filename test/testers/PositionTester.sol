// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { PerpStorage } from "../../src/storages/PerpStorage.sol";
import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

import { MockOracleMiddleware } from "../mocks/MockOracleMiddleware.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

contract PositionTester is StdAssertions {
  struct DecreasePositionAssertionData {
    uint256 decreasedPositionSize;
    uint256 reserveValueDelta;
    uint256 openInterestDelta;
    // average price
    uint256 newPositionAveragePrice;
    uint256 newLongGlobalAveragePrice;
    uint256 newShortGlobalAveragePrice;
  }

  PerpStorage perpStorage;
  MockOracleMiddleware oracle;

  bytes32 cachePositionId;
  IPerpStorage.Position cachePosition;
  IPerpStorage.GlobalMarket cacheMarketGlobal;
  IPerpStorage.GlobalState cacheGlobalState;

  constructor(PerpStorage _perpStorage, MockOracleMiddleware _oracle) {
    perpStorage = _perpStorage;
    oracle = _oracle;
  }

  function watch(bytes32 _positionId) external {
    // @todo - this can access state directly
    cachePositionId = _positionId;
    cachePosition = perpStorage.getPositionById(_positionId);
    cacheMarketGlobal = perpStorage.getGlobalMarketByIndex(cachePosition.marketIndex);
    cacheGlobalState = perpStorage.getGlobalState();
  }

  // assert cache position with current position from storage
  // what this function check after decrease position
  // - position
  //    - size delta
  //    - reserve delta
  //    - average price
  //    - open interest
  // - global market
  //    - long / short position size
  //    - long / short open interest
  //    - long / short average price
  //    - [pending] funding rate
  // - global state
  //    - reserve value delta
  //    - [pending] sum of borrowing fee
  function assertDecreasePositionResult(DecreasePositionAssertionData memory _data) external {
    // assert position state
    IPerpStorage.Position memory _currentPosition = perpStorage.getPositionById(cachePositionId);
    int256 _sizeDelta = cachePosition.positionSizeE30 - _currentPosition.positionSizeE30;

    assertEq(uint256(_sizeDelta > 0 ? _sizeDelta : -_sizeDelta), _data.decreasedPositionSize, "position size");
    assertEq(_currentPosition.avgEntryPriceE30, _data.newPositionAveragePrice, "position average price");
    assertEq(
      cachePosition.reserveValueE30 - _currentPosition.reserveValueE30,
      _data.reserveValueDelta,
      "position reserve value"
    );
    assertEq(
      cachePosition.openInterest - _currentPosition.openInterest,
      _data.openInterestDelta,
      "position open interest"
    );

    // assert market global
    IPerpStorage.GlobalMarket memory _currentMarketGlobal = perpStorage.getGlobalMarketByIndex(
      _currentPosition.marketIndex
    );

    if (cachePosition.positionSizeE30 > 0) {
      // check global LONG position
      assertEq(
        cacheMarketGlobal.longPositionSize - _currentMarketGlobal.longPositionSize,
        _data.decreasedPositionSize,
        "market long position size"
      );
      assertEq(_currentMarketGlobal.longAvgPrice, _data.newLongGlobalAveragePrice, "global long average price");
      assertEq(
        cacheMarketGlobal.longOpenInterest - _currentMarketGlobal.longOpenInterest,
        _data.openInterestDelta,
        "market long open interest"
      );
    } else {
      // check global SHORT position
      assertEq(
        cacheMarketGlobal.shortPositionSize - _currentMarketGlobal.shortPositionSize,
        _data.decreasedPositionSize,
        "market short position size"
      );
      assertEq(_currentMarketGlobal.shortAvgPrice, _data.newShortGlobalAveragePrice, "global short average price");
      assertEq(
        cacheMarketGlobal.shortOpenInterest - _currentMarketGlobal.shortOpenInterest,
        _data.openInterestDelta,
        "market short open interest"
      );
    }

    // todo: support on funding rate calculation story
    // assertEq(cacheMarketGlobal.fundingRate - _currentMarketGlobal.fundingRate, 0);
    // assertEq(_currentMarketGlobal.lastFundingTime, block.timestamp);

    // assert global state
    IPerpStorage.GlobalState memory _globalState = perpStorage.getGlobalState();
    assertEq(
      cacheGlobalState.reserveValueE30 - _globalState.reserveValueE30,
      _data.reserveValueDelta,
      "global reserve value"
    );
    // todo: support on borrowing fee story
    // assertEq(
    //   cacheGlobalState.sumBorrowingRate - _globalState.sumBorrowingRate,
    //   _data.reserveValueDelta
    // );
    // assertEq(
    //   cacheGlobalState.lastBorrowingTime,
    //   block.timestamp
    // );
  }
}
