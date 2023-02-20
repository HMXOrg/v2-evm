// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IOracleMiddleware {
  // errors
  error IOracleMiddleware_PythPriceStale();
  error IOracleMiddleware_MarketStatusUndefined();
  error IOracleMiddleware_OnlyUpdater();
  error IOracleMiddleware_InvalidMarketStatus();

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidentTreshold,
    uint256 _trustPriceAge
  ) external view returns (uint256 _price, uint256 _lastUpdated);

  function getLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold,
    uint256 _trustPriceAge
  ) external view returns (uint256 _price, uint256 _lastUpdated, uint8 _status);

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================

  function unsafeGetLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidentTreshold
  ) external view returns (uint256 _price, uint256 _lastUpdated);

  function unsafeGetLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold
  ) external view returns (uint256 _price, uint256 _lastUpdated, uint8 _status);
}
