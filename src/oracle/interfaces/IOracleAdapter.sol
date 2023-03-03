// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IOracleAdapter {
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint32 _confidenceThreshold
  ) external view returns (uint256, int32, uint256);

  function isSameAsset(bytes32 _assetId1, bytes32 _assetId2) external view returns (bool);
}
