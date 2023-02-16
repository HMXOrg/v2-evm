// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IOracleMiddleware {
  /// @notice Get the latest price of the given asset. Returned price is in 30 decimals.
  /// @dev The price returns here can be staled.
  /// @param _assetId The asset id to get price.
  /// @param _isMax Whether to use the max price or min price.
  /// @param _confidentTreshold threshold to validate price confidential
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidentTreshold
  ) external view returns (uint256, uint256);

  function getLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status);
}
