// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is IPerpStorage {
  GlobalState public globalState; // global state that accumulative value from all markets

  Position[] public positions;
  mapping(bytes32 => uint256) public positionIndices; // bytes32 = primaryAccount + subAccount + marketIndex
  // sub account => position indices
  mapping(address => uint256[]) public subAccountPositionIndices;

  mapping(address => CollateralToken) public collateralTokens;
  mapping(uint256 => GlobalMarket) public globalMarkets;

  constructor() {}

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function getPositionBySubAccount(
    address _trader
  ) external view returns (Position[] memory traderPositions) {
    uint256[] memory _subAccountPositionIndices = subAccountPositionIndices[
      _trader
    ];
    if (_subAccountPositionIndices.length > 0) {
      Position[] memory _traderPositions = new Position[](
        _subAccountPositionIndices.length
      );

      for (uint i; i < _subAccountPositionIndices.length; ) {
        uint _subAccountPositionIndex = _subAccountPositionIndices[i];
        _traderPositions[i] = (positions[_subAccountPositionIndex]);

        unchecked {
          i++;
        }
      }

      return _traderPositions;
    }
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
}
