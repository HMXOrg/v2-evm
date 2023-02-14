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

  mapping(address => CollateralToken) public collateralTokens;
  mapping(uint256 => GlobalMarket) public globalMarkets;

  constructor() {}

  // todo: add description
  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory) {
    uint256 _index = positionIndices[_positionId];
    return positions[_index];
  }

  // todo: add description
  // todo: support to update borrowing rate
  // todo: support to update funding rate
  function setPositionById(
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
}
