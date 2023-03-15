// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

import { Owned } from "../base/Owned.sol";

/// @title PerpStorage
/// @notice storage contract to keep core feature state
contract PerpStorage is Owned, ReentrancyGuard, IPerpStorage {
  /**
   * Modifiers
   */
  modifier onlyWhitelistedExecutor() {
    if (!serviceExecutors[msg.sender]) revert IPerpStorage_NotWhiteListed();
    _;
  }

  /**
   * Events
   */
  event SetServiceExecutor(address indexed executorAddress, bool isServiceExecutor);

  /**
   * States
   */
  GlobalState public globalState; // global state that accumulative value from all markets

  mapping(bytes32 => Position) public positions;
  mapping(address => bytes32[]) public subAccountPositionIds;
  mapping(address => int256) public subAccountFee;
  mapping(address => uint256) public badDebt;
  mapping(uint256 => GlobalMarket) public globalMarkets;
  mapping(uint256 => GlobalAssetClass) public globalAssetClass;
  mapping(address => bool) public serviceExecutors;

  /**
   * Getter
   */

  /// @notice Get all positions with a specific trader's sub-account
  /// @param _trader The address of the trader whose positions to retrieve
  /// @return traderPositions An array of Position objects representing the trader's positions
  function getPositionBySubAccount(address _trader) external view returns (Position[] memory traderPositions) {
    bytes32[] memory _positionIds = subAccountPositionIds[_trader];
    if (_positionIds.length > 0) {
      Position[] memory _traderPositions = new Position[](_positionIds.length);
      uint256 _len = _positionIds.length;
      for (uint256 i; i < _len; ) {
        _traderPositions[i] = (positions[_positionIds[i]]);

        unchecked {
          i++;
        }
      }

      return _traderPositions;
    }
  }

  function getPositionIds(address _subAccount) external view returns (bytes32[] memory _positionIds) {
    return subAccountPositionIds[_subAccount];
  }

  // @todo - add description
  function getPositionById(bytes32 _positionId) external view returns (Position memory) {
    return positions[_positionId];
  }

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256) {
    return subAccountPositionIds[_subAccount].length;
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

  /**
   * Setter
   */

  function setServiceExecutors(address _executorAddress, bool _isServiceExecutor) external onlyOwner nonReentrant {
    serviceExecutors[_executorAddress] = _isServiceExecutor;
    emit SetServiceExecutor(_executorAddress, _isServiceExecutor);
  }

  function savePosition(
    address _subAccount,
    bytes32 _positionId,
    Position calldata position
  ) external nonReentrant onlyWhitelistedExecutor {
    IPerpStorage.Position memory _position = positions[_positionId];
    // register new position for trader's sub-account
    if (_position.positionSizeE30 == 0) {
      subAccountPositionIds[_subAccount].push(_positionId);
    }
    positions[_positionId] = position;
  }

  /// @notice Resets the position associated with the given position ID.
  /// @param _subAccount The sub account of the position.
  /// @param _positionId The ID of the position to be reset.
  function removePositionFromSubAccount(address _subAccount, bytes32 _positionId) external onlyWhitelistedExecutor {
    bytes32[] storage _positionIds = subAccountPositionIds[_subAccount];
    uint256 _len = _positionIds.length;
    for (uint256 _i; _i < _len; ) {
      if (_positionIds[_i] == _positionId) {
        _positionIds[_i] = _positionIds[_len - 1];
        _positionIds.pop();
        delete positions[_positionId];

        break;
      }

      unchecked {
        ++_i;
      }
    }
  }

  // @todo - update funding rate
  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    uint256 _newOpenInterest
  ) external onlyWhitelistedExecutor {
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
  ) external onlyWhitelistedExecutor {
    globalMarkets[_marketIndex].shortPositionSize = _newPositionSize;
    globalMarkets[_marketIndex].shortAvgPrice = _newAvgPrice;
    globalMarkets[_marketIndex].shortOpenInterest = _newOpenInterest;
  }

  function updateGlobalState(GlobalState memory _newGlobalState) external onlyWhitelistedExecutor {
    globalState = _newGlobalState;
  }

  function updateGlobalAssetClass(
    uint8 _assetClassIndex,
    GlobalAssetClass memory _newAssetClass
  ) external onlyWhitelistedExecutor {
    globalAssetClass[_assetClassIndex] = _newAssetClass;
  }

  function updateGlobalMarket(
    uint256 _marketIndex,
    GlobalMarket memory _globalMarket
  ) external onlyWhitelistedExecutor {
    globalMarkets[_marketIndex] = _globalMarket;
  }

  function updateSubAccountFee(address _subAccount, int256 fee) external onlyWhitelistedExecutor {
    subAccountFee[_subAccount] = fee;
  }

  /// @notice Adds bad debt to the specified sub-account.
  /// @param _subAccount The address of the sub-account to add bad debt to.
  /// @param _badDebt The amount of bad debt to add to the sub-account.
  function addBadDebt(address _subAccount, uint256 _badDebt) external onlyWhitelistedExecutor {
    // Add the bad debt to the sub-account
    badDebt[_subAccount] += _badDebt;
  }

  function increaseReserved(uint8 _assetClassIndex, uint256 _reserve) external onlyWhitelistedExecutor {
    globalState.reserveValueE30 += _reserve;
    globalAssetClass[_assetClassIndex].reserveValueE30 += _reserve;
  }

  function decreaseReserved(uint8 _assetClassIndex, uint256 _reserve) external onlyWhitelistedExecutor {
    globalState.reserveValueE30 -= _reserve;
    globalAssetClass[_assetClassIndex].reserveValueE30 -= _reserve;
  }

  function increaseOpenInterest(uint256 _marketIndex, bool _isLong, uint256 _size, uint256 _openInterest) external {
    if (_isLong) {
      globalMarkets[_marketIndex].longPositionSize += _size;
      globalMarkets[_marketIndex].longOpenInterest += _openInterest;
    } else {
      globalMarkets[_marketIndex].shortPositionSize += _size;
      globalMarkets[_marketIndex].shortOpenInterest += _openInterest;
    }
  }

  function decreaseOpenInterest(uint256 _marketIndex, bool _isLong, uint256 _size, uint256 _openInterest) external {
    if (_isLong) {
      globalMarkets[_marketIndex].longPositionSize -= _size;
      globalMarkets[_marketIndex].longOpenInterest -= _openInterest;
    } else {
      globalMarkets[_marketIndex].shortPositionSize -= _size;
      globalMarkets[_marketIndex].shortOpenInterest -= _openInterest;
    }
  }

  function updateGlobalMarketPrice(uint256 _marketIndex, bool _isLong, uint256 _price) external {
    if (_isLong) {
      globalMarkets[_marketIndex].longAvgPrice = _price;
    } else {
      globalMarkets[_marketIndex].shortAvgPrice = _price;
    }
  }
}
