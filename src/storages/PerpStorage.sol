// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
abstract contract PerpStorage is IPerpStorage {
  GlobalState public globalState; // global state that accumulative value from all markets

  Position[] public positions;
  mapping(bytes32 => uint256) public positionIndices; // bytes32 = primaryAccount + subAccount + marketIndex

  mapping(address => uint256[]) public subAccountPositionIndices;

  mapping(address => CollateralToken) public collateralTokens;

  mapping(uint256 => GlobalMarket) public globalMarkets;

  constructor() {}

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function getGlobalState() external view returns (GlobalState memory) {
    return globalState;
  }

  function getGlobalMarketById(
    uint256 _marketId
  ) external view returns (GlobalMarket memory) {
    return globalMarkets[_marketId];
  }

  // sub account => position indices
  function getPositionById(
    bytes32 _positionId
  ) external view returns (Position memory) {
    uint256 _index = positionIndices[_positionId];
    return positions[_index];
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function updateReserveValue(uint256 newReserveValue) external {
    globalState.reserveValueE30 = newReserveValue;
  }

  function savePosition(
    bytes32 _positionId,
    Position calldata position
  ) public {
    uint256 _index = positionIndices[_positionId];
    if (_index == 0) {
      positionIndices[_positionId] = positions.length;
      positions.push(position);
    } else {
      positions[_index] = position;
    }
  }
}
