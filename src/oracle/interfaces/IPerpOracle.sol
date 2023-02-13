// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPerpOracle {
  /// @notice Get the latest price of the given asset. Returned price is in 30 decimals.
  /// @dev The price returns here can be staled.
  /// @param _assetId The asset id to get price.
  /// @param _isMax Whether to use the max price or min price.
  /// @param _confidentTreshold threshold to validate price confidential
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint8 _confidentTreshold
  ) external view returns (uint256, uint256);

  /// @notice Update prices.
  /// @dev The price returns here can be staled.
  /// @param _updateData price data to update.
  function updatePrices(bytes[] calldata _updateData) external;
}
