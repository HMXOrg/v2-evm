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

  mapping(address => uint256[]) public subAccountPositionIndices; // sub account => position indices

  mapping(address => int256) public subAccountFee;

  mapping(address => uint256) public badDebt;

  mapping(address => CollateralToken) public collateralTokens;

  mapping(uint256 => GlobalMarket) public globalMarkets;

  mapping(uint256 => GlobalAssetClass) public globalAssetClass;

  constructor() {
    positions.push(
      Position({
        primaryAccount: address(0),
        subAccountId: 0,
        marketIndex: 0,
        positionSizeE30: 0,
        avgEntryPriceE30: 0,
        entryBorrowingRate: 0,
        entryFundingRate: 0,
        reserveValueE30: 0,
        lastIncreaseTimestamp: 0,
        realizedPnl: 0,
        openInterest: 0
      })
    );
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER
  ////////////////////////////////////////////////////////////////////////////////////

  function getPositionBySubAccount(address _trader) external view returns (Position[] memory traderPositions) {
    uint256[] memory _subAccountPositionIndices = subAccountPositionIndices[_trader];
    if (_subAccountPositionIndices.length > 0) {
      Position[] memory _traderPositions = new Position[](_subAccountPositionIndices.length);

      for (uint256 i; i < _subAccountPositionIndices.length; ) {
        uint256 _subAccountPositionIndex = _subAccountPositionIndices[i];
        _traderPositions[i] = (positions[_subAccountPositionIndex]);

        unchecked {
          i++;
        }
      }

      return _traderPositions;
    }
  }

  // @todo - add description
  function getPositionById(bytes32 _positionId) external view returns (Position memory) {
    uint256 _index = positionIndices[_positionId];
    return positions[_index];
  }

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256) {
    return subAccountPositionIndices[_subAccount].length;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function savePosition(address _subAccount, bytes32 _positionId, Position calldata position) public {
    uint256 _index = positionIndices[_positionId];
    if (_index == 0) {
      positionIndices[_positionId] = positions.length;
      subAccountPositionIndices[_subAccount].push(positions.length);
      positions.push(position);
    } else {
      positions[_index] = position;
    }
  }

  /// @notice Resets the position associated with the given position ID.
  /// @param _positionId The ID of the position to be reset.
  function resetPosition(bytes32 _positionId) public {
    uint256 _index = positionIndices[_positionId];
    // Delete the position at the specified index
    delete positions[_index];
  }

  // @todo - remove
  function addPosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30,
    uint256 _newOpenInterest
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
        realizedPnl: 0,
        openInterest: _newOpenInterest
      })
    );
    positionIndices[_positionId] = positions.length - 1;
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

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER
  ////////////////////////////////////////////////////////////////////////////////////

  // @todo - add description
  // @todo - support to update borrowing rate
  // @todo - support to update funding rate
  function updatePositionById(
    bytes32 _positionId,
    int256 _newPositionSizeE30,
    uint256 _newReserveValueE30,
    uint256 _newAvgPriceE30,
    uint256 _newOpenInterest
  ) external returns (Position memory _position) {
    uint256 _index = positionIndices[_positionId];
    _position = positions[_index];
    _position.positionSizeE30 = _newPositionSizeE30;
    _position.reserveValueE30 = _newReserveValueE30;
    _position.avgEntryPriceE30 = _newAvgPriceE30;
    _position.openInterest = _newOpenInterest;
    positions[_index] = _position;
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
