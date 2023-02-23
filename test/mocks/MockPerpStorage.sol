// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IPerpStorage } from "../../src/storages/interfaces/IPerpStorage.sol";

contract MockPerpStorage {
  mapping(address => IPerpStorage.Position[]) public positions;

  mapping(uint256 => IPerpStorage.GlobalAssetClass) public globalAssetClass;

  mapping(bytes32 => IPerpStorage.Position) public positionById;

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getPositionBySubAccount(
    address _subAccount
  ) external view returns (IPerpStorage.Position[] memory traderPositions) {
    return positions[_subAccount];
  }

  function getGlobalAssetClassByIndex(
    uint256 _assetClassIndex
  ) external view returns (IPerpStorage.GlobalAssetClass memory) {
    return globalAssetClass[_assetClassIndex];
  }

  function getPositionById(bytes32 _positionId) external view returns (IPerpStorage.Position memory) {
    return positionById[_positionId];
  }

  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function setPositionBySubAccount(address _subAccount, IPerpStorage.Position memory _position) external {
    positions[_subAccount].push(_position);
    positionById[_getPositionId(_subAccount, _position.marketIndex)] = _position;
  }

  function updateGlobalAssetClass(
    uint256 _assetClassIndex,
    IPerpStorage.GlobalAssetClass memory _newAssetClass
  ) external {
    globalAssetClass[_assetClassIndex] = _newAssetClass;
  }
}
