// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

contract MockPerpStorage {
  mapping(address => IPerpStorage.Position[]) public positions;
  mapping(uint256 => IPerpStorage.Market) public markets;

  mapping(uint8 => IPerpStorage.AssetClass) public assetClasses;

  mapping(bytes32 => IPerpStorage.Position) public positionById;

  IPerpStorage.GlobalState public globalState; // global state that accumulative value from all markets

  /**
   * Getter
   */

  function getGlobalState() external view returns (IPerpStorage.GlobalState memory) {
    return globalState;
  }

  function getPositionBySubAccount(
    address _subAccount
  ) external view returns (IPerpStorage.Position[] memory traderPositions) {
    return positions[_subAccount];
  }

  function getAssetClassByIndex(uint8 _assetClassIndex) external view returns (IPerpStorage.AssetClass memory) {
    return assetClasses[_assetClassIndex];
  }

  function getPositionById(bytes32 _positionId) external view returns (IPerpStorage.Position memory) {
    return positionById[_positionId];
  }

  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  function getMarketByIndex(uint256 _marketIndex) external view returns (IPerpStorage.Market memory) {
    return markets[_marketIndex];
  }

  /**
   * Setter
   */

  function setPositionBySubAccount(address _subAccount, IPerpStorage.Position memory _position) external {
    positions[_subAccount].push(_position);
    positionById[_getPositionId(_subAccount, _position.marketIndex)] = _position;
  }

  // @todo - update funding rate
  function updateGlobalLongMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    int256 _newAccumFundingLong,
    int256 _currentFundingRate
  ) external {
    markets[_marketIndex].longPositionSize = _newPositionSize;
    markets[_marketIndex].longAvgPrice = _newAvgPrice;
    markets[_marketIndex].accumFundingLong = _newAccumFundingLong;
    markets[_marketIndex].currentFundingRate = _currentFundingRate;
  }

  // @todo - update funding rate
  function updateGlobalShortMarketById(
    uint256 _marketIndex,
    uint256 _newPositionSize,
    uint256 _newAvgPrice,
    int256 _newAccumFundingShort,
    int256 _currentFundingRate
  ) external {
    markets[_marketIndex].shortPositionSize = _newPositionSize;
    markets[_marketIndex].shortAvgPrice = _newAvgPrice;
    markets[_marketIndex].accumFundingShort = _newAccumFundingShort;
    markets[_marketIndex].currentFundingRate = _currentFundingRate;
  }

  function updateAssetClass(uint8 _assetClassIndex, IPerpStorage.AssetClass memory _newAssetClass) external {
    assetClasses[_assetClassIndex] = _newAssetClass;
  }
}
