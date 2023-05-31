// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { console } from "forge-std/console.sol";

contract PositionTester is StdAssertions {
  struct DecreasePositionAssertionData {
    address primaryAccount;
    uint8 subAccountId;
    // position info
    uint256 decreasedPositionSize;
    uint256 reserveValueDelta;
    int256 realizedPnl;
    // average price
    uint256 newPositionAveragePrice;
    uint256 newLongGlobalAveragePrice;
    uint256 newShortGlobalAveragePrice;
  }

  IPerpStorage perpStorage;
  IVaultStorage vaultStorage;
  IOracleMiddleware oracle;

  // cache position info
  bytes32 cachePositionId;
  IPerpStorage.Position cachePosition;
  // cache perp storage
  IPerpStorage.Market cacheMarket;
  IPerpStorage.GlobalState cacheGlobalState;
  // cache vault storage
  uint256 cachePlpTokenLiquidity;
  uint256 cacheTraderBalance;

  constructor(IPerpStorage _perpStorage, IVaultStorage _vaultStorage, IOracleMiddleware _oracle) {
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    oracle = _oracle;
  }

  function watch(address _primaryAccount, uint8 _subAccountId, address _token, bytes32 _positionId) external {
    address _subAccount = _getSubAccount(_primaryAccount, _subAccountId);
    // @todo - this can access state directly
    cachePositionId = _positionId;
    cachePosition = perpStorage.getPositionById(_positionId);
    cacheMarket = perpStorage.getMarketByIndex(cachePosition.marketIndex);
    cacheGlobalState = perpStorage.getGlobalState();

    cachePlpTokenLiquidity = vaultStorage.hlpLiquidity(_token);
    cacheTraderBalance = vaultStorage.traderBalances(_subAccount, _token);
  }

  // assert cache position with current position from storage
  // what this function check after decrease position
  // - sub account
  //   - free collateral
  // - perp storage
  //   - liquidity
  // - position
  //   - size delta
  //   - reserve delta
  //   - average price
  // - global market
  //   - long / short position size
  //   - long / short average price
  //   - [pending] funding rate
  // - global state
  //   - reserve value delta
  //   - [pending] sum of borrowing fee
  function assertDecreasePositionResult(
    DecreasePositionAssertionData memory _data,
    address[] calldata _hlpTokens,
    uint256[] calldata _expectedBalances,
    uint256[] calldata _expectedPlpLiquidities,
    uint256[] calldata _expectedFees
  ) external {
    address _subAccount = _getSubAccount(_data.primaryAccount, _data.subAccountId);

    {
      uint256 _len = _hlpTokens.length;
      // collateral
      address _token;
      uint256 _expectBalance;
      uint256 _expectLiquidity;
      uint256 _expectFee;
      for (uint256 _i; _i < _len; ) {
        _token = _hlpTokens[_i];
        _expectBalance = _expectedBalances[_i];
        _expectLiquidity = _expectedPlpLiquidities[_i];
        _expectFee = _expectedFees[_i];

        assertEq(vaultStorage.traderBalances(_subAccount, _token), _expectBalance, "trader balance");
        assertEq(vaultStorage.hlpLiquidity(_token), _expectLiquidity, "liquidity");
        assertEq(vaultStorage.protocolFees(_token), _expectFee, "protocol fee");

        unchecked {
          ++_i;
        }
      }
    }

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

    assertEq(_currentPosition.realizedPnl, _data.realizedPnl, "position realized pnl");

    // assert market global
    IPerpStorage.Market memory _currentMarket = perpStorage.getMarketByIndex(_currentPosition.marketIndex);

    if (cachePosition.positionSizeE30 > 0) {
      // check global LONG position
      assertEq(
        cacheMarket.longPositionSize - _currentMarket.longPositionSize,
        _data.decreasedPositionSize,
        "market long position size"
      );
    } else {
      // check global SHORT position
      assertEq(
        cacheMarket.shortPositionSize - _currentMarket.shortPositionSize,
        _data.decreasedPositionSize,
        "market short position size"
      );
    }

    // todo: support on funding rate calculation story
    // assertEq(cacheMarket.fundingRate - _currentMarket.fundingRate, 0);
    // assertEq(_currentMarket.lastFundingTime, block.timestamp);

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

  function _getSubAccount(address _primaryAccount, uint8 _subAccountId) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primaryAccount) ^ uint160(_subAccountId));
  }
}
