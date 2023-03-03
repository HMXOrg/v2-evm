// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is IPerpStorage {
  GlobalState public globalState; // global state that accumulative value from all markets

  bytes32[] public positionIds;
  mapping(bytes32 => Position) public positions;
  mapping(address => bytes32[]) public subAccountPositionIds;

  mapping(address => int256) public subAccountFee;

  mapping(address => uint256) public badDebt;

  mapping(uint256 => GlobalMarket) public globalMarkets;

  mapping(uint256 => GlobalAssetClass) public globalAssetClass;

  /// @notice Get all positions with a specific trader's sub-account
  /// @param _trader The address of the trader whose positions to retrieve
  /// @return traderPositions An array of Position objects representing the trader's positions
  function getPositionBySubAccount(address _trader) external view returns (Position[] memory traderPositions) {
    bytes32[] memory _subAccountPositionIds = subAccountPositionIds[_trader];
    if (_subAccountPositionIds.length > 0) {
      Position[] memory _traderPositions = new Position[](_subAccountPositionIds.length);
      uint256 _len = _subAccountPositionIds.length;
      for (uint256 i; i < _len; ) {
        _traderPositions[i] = (positions[_subAccountPositionIds[i]]);

        unchecked {
          i++;
        }
      }

      return _traderPositions;
    }
  }

  // @todo - add description
  function getPositionById(bytes32 _positionId) external view returns (Position memory) {
    return positions[_positionId];
  }

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256) {
    return subAccountPositionIds[_subAccount].length;
  }

  function savePosition(address _subAccount, bytes32 _positionId, Position calldata position) public {
    IPerpStorage.Position memory _position = positions[_positionId];
    if (_position.positionSizeE30 == 0) {
      positionIds.push(_positionId);
      subAccountPositionIds[_subAccount].push(_positionId);
    }
    positions[_positionId] = position;
  }

  /// @notice Resets the position associated with the given position ID.
  /// @param _positionId The ID of the position to be reset.
  function resetPosition(bytes32 _positionId) public {
    uint256 _len = positionIds.length;
    for (uint256 i; i < _len; ) {
      if (positionIds[i] == _positionId) {
        positionIds[i] = positionIds[_len - 1];
        positionIds.pop();
        delete positions[_positionId];

        break;
      }

      unchecked {
        ++i;
      }
    }
  }

  // todo: add description
  // todo: support to update borrowing rate
  // todo: support to update funding rate
  function getGlobalMarketByIndex(uint256 _marketIndex) external view returns (GlobalMarket memory) {
    return globalMarkets[_marketIndex];
  }

  function getGlobalAssetClassByIndex(uint256 _assetClassIndex) external view returns (GlobalAssetClass memory) {
    return globalAssetClass[_assetClassIndex];
  }

  function getGlobalState() external view returns (GlobalState memory) {
    return globalState;
  }

  function getSubAccountFee(address subAccount) external view returns (int256 fee) {
    return subAccountFee[subAccount];
  }

  /// @notice Gets the bad debt associated with the given sub-account.
  /// @param subAccount The address of the sub-account to get the bad debt for.
  /// @return _badDebt The bad debt associated with the given sub-account.
  function getBadDebt(address subAccount) external view returns (uint256 _badDebt) {
    return badDebt[subAccount];
  }

  // @todo - update funding rate
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

  // @todo - update funding rate
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

  function updateGlobalState(GlobalState memory _newGlobalState) external {
    globalState = _newGlobalState;
  }

  function updateGlobalAssetClass(uint256 _assetClassIndex, GlobalAssetClass memory _newAssetClass) external {
    globalAssetClass[_assetClassIndex] = _newAssetClass;
  }

  function updateGlobalMarket(uint256 _marketIndex, GlobalMarket memory _globalMarket) external {
    globalMarkets[_marketIndex] = _globalMarket;
  }

  function updateSubAccountFee(address _subAccount, int256 fee) external {
    subAccountFee[_subAccount] = fee;
  }

  /// @notice Adds bad debt to the specified sub-account.
  /// @param _subAccount The address of the sub-account to add bad debt to.
  /// @param _badDebt The amount of bad debt to add to the sub-account.
  function addBadDebt(address _subAccount, uint256 _badDebt) external {
    // Add the bad debt to the sub-account
    badDebt[_subAccount] += _badDebt;
  }
}
