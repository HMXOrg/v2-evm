// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// interfaces
import { IPerpStorage } from "./interfaces/IPerpStorage.sol";

import { Owned } from "@hmx/base/Owned.sol";

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
  event LogSetServiceExecutor(address indexed executorAddress, bool isServiceExecutor);

  /**
   * States
   */
  GlobalState public globalState; // global state that accumulative value from all markets

  mapping(bytes32 => Position) public positions;
  mapping(address => bytes32[]) public subAccountPositionIds;
  mapping(address => uint256) public subAccountBorrowingFee;
  mapping(uint256 => Market) public markets;
  mapping(uint256 => AssetClass) public assetClasses;
  mapping(address => bool) public serviceExecutors;

  /**
   * Getter
   */
  /// @notice Get all positions with a specific trader's sub-account
  /// @param _subAccount The address of the trader whose positions to retrieve
  /// @return _subAccountPositions An array of Position objects representing the trader's positions
  function getPositionBySubAccount(address _subAccount) external view returns (Position[] memory _subAccountPositions) {
    bytes32[] memory _positionIds = subAccountPositionIds[_subAccount];
    uint256 _len = _positionIds.length;

    if (_len == 0) return _subAccountPositions;

    _subAccountPositions = new Position[](_positionIds.length);

    for (uint256 _i; _i < _len; ) {
      _subAccountPositions[_i] = (positions[_positionIds[_i]]);

      unchecked {
        ++_i;
      }
    }

    return _subAccountPositions;
  }

  function getPositionIds(address _subAccount) external view returns (bytes32[] memory _positionIds) {
    return subAccountPositionIds[_subAccount];
  }

  function getPositionById(bytes32 _positionId) external view returns (Position memory) {
    return positions[_positionId];
  }

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256) {
    return subAccountPositionIds[_subAccount].length;
  }

  function getMarketByIndex(uint256 _marketIndex) external view returns (Market memory) {
    return markets[_marketIndex];
  }

  function getAssetClassByIndex(uint256 _assetClassIndex) external view returns (AssetClass memory) {
    return assetClasses[_assetClassIndex];
  }

  function getGlobalState() external view returns (GlobalState memory) {
    return globalState;
  }

  /**
   * Setters
   */
  function setServiceExecutors(address _executorAddress, bool _isServiceExecutor) external onlyOwner nonReentrant {
    serviceExecutors[_executorAddress] = _isServiceExecutor;
    emit LogSetServiceExecutor(_executorAddress, _isServiceExecutor);
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

  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice
  ) external onlyWhitelistedExecutor {
    markets[_marketIndex].longPositionSize = _newPositionSize;
    markets[_marketIndex].longAvgPrice = _newAvgPrice;
  }

  function updateGlobalShortMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice
  ) external onlyWhitelistedExecutor {
    markets[_marketIndex].shortPositionSize = _newPositionSize;
    markets[_marketIndex].shortAvgPrice = _newAvgPrice;
  }

  function updateGlobalState(GlobalState memory _newGlobalState) external onlyWhitelistedExecutor {
    globalState = _newGlobalState;
  }

  function updateAssetClass(uint8 _assetClassIndex, AssetClass memory _newAssetClass) external onlyWhitelistedExecutor {
    assetClasses[_assetClassIndex] = _newAssetClass;
  }

  function updateMarket(uint256 _marketIndex, Market memory _market) external onlyWhitelistedExecutor {
    markets[_marketIndex] = _market;
  }

  function increaseSubAccountBorrowingFee(address _subAccount, uint256 _borrowingFee) external onlyWhitelistedExecutor {
    subAccountBorrowingFee[_subAccount] += _borrowingFee;
  }

  function decreaseSubAccountBorrowingFee(address _subAccount, uint256 _borrowingFee) external onlyWhitelistedExecutor {
    // Maximum decrease the current amount
    if (subAccountBorrowingFee[_subAccount] < _borrowingFee) {
      subAccountBorrowingFee[_subAccount] = 0;
      return;
    }

    subAccountBorrowingFee[_subAccount] -= _borrowingFee;
  }

  function increaseReserved(uint8 _assetClassIndex, uint256 _reserve) external onlyWhitelistedExecutor {
    globalState.reserveValueE30 += _reserve;
    assetClasses[_assetClassIndex].reserveValueE30 += _reserve;
  }

  function decreaseReserved(uint8 _assetClassIndex, uint256 _reserve) external onlyWhitelistedExecutor {
    globalState.reserveValueE30 -= _reserve;
    assetClasses[_assetClassIndex].reserveValueE30 -= _reserve;
  }

  function increasePositionSize(uint256 _marketIndex, bool _isLong, uint256 _size) external onlyWhitelistedExecutor {
    if (_isLong) {
      markets[_marketIndex].longPositionSize += _size;
    } else {
      markets[_marketIndex].shortPositionSize += _size;
    }
  }

  function decreasePositionSize(uint256 _marketIndex, bool _isLong, uint256 _size) external onlyWhitelistedExecutor {
    if (_isLong) {
      markets[_marketIndex].longPositionSize -= _size;
    } else {
      markets[_marketIndex].shortPositionSize -= _size;
    }
  }

  function updateMarketPrice(uint256 _marketIndex, bool _isLong, uint256 _price) external onlyWhitelistedExecutor {
    if (_isLong) {
      markets[_marketIndex].longAvgPrice = _price;
    } else {
      markets[_marketIndex].shortAvgPrice = _price;
    }
  }
}
