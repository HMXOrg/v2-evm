// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is IPerpStorage {
  GlobalState public globalState; // global state that accumulative value from all markets

  Position[] public positions;
  mapping(bytes32 => uint256) public positionIndices; // bytes32 = primaryAccount + subAccount + marketIndex
  // sub account => position indices
  mapping(address => uint256[]) public subAccountPositionIndices;

  mapping(address => CollateralToken) public collateralTokens;
  // market id => GlobalMarket
  mapping(uint256 => GlobalMarket) public globalMarkets;

  constructor() {}

  // todo: add description
  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory) {
    uint256 _index = positionIndices[_positionId];
    return positions[_index];
  }

  // todo: remove
  function addPosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30
  ) external {
    positions.push(
      Position({
        primaryAccount: _primaryAccount,
        subAccountId: _subAccountId,
        marketIndex: _marketIndex,
        positionSizeE30: _newPositionSizeE30,
        avgEntryPriceE30: _newAvgPriceE30,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: _newReserveValueE30,
        lastIncreaseTimestamp: block.timestamp,
        realizedPnl: 0
      })
    );
    positionIndices[_positionId] = positions.length - 1;
  }

  function getGlobalMarketByIndex(
    uint256 _marketIndex
  ) external view returns (GlobalMarket memory) {
    return globalMarkets[_marketIndex];
  }

  // todo: add description
  // todo: support to update borrowing rate
  // todo: support to update funding rate
  function updatePositionById(
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30
  ) external returns (Position memory _position) {
    uint256 _index = positionIndices[_positionId];
    _position = positions[_index];
    _position.positionSizeE30 = _newPositionSizeE30;
    _position.reserveValueE30 = _newReserveValueE30;
    _position.avgEntryPriceE30 = _newAvgPriceE30;
    positions[_index] = _position;
  }

  // todo: update funding rate
  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external {
    globalMarkets[_marketIndex].longPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].longAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].longOpenInterest = _newOpenInterest;
  }

  // todo: update funding rate
  function updateGlobalShortMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external {
    globalMarkets[_marketIndex].shortPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].shortAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].shortOpenInterest = _newOpenInterest;
  }
}
