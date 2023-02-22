// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IOracleMiddleware } from "../../src/oracle/interfaces/IOracleMiddleware.sol";

contract MockOracleMiddleware is IOracleMiddleware {
  uint256 public priceE30;
  uint256 public lastUpdate;
  uint8 public marketStatus;
  bool public isPriceStale;

  struct Price {
    uint256 priceE30;
    uint256 lastUpdate;
    uint256 marketStatus;
  }

  mapping(bytes32 => Price) price;

  constructor() {
    priceE30 = 1e30;
    lastUpdate = block.timestamp;
    marketStatus = 2;
  }

  // =========================================
  // | ---------- Setter ------------------- |
  // =========================================
  function setPrice(bytes32 _assetId, uint256 _newPriceE30) external {
    price[_assetId] = Price({ priceE30: _newPriceE30, lastUpdate: block.timestamp, marketStatus: 2 });
  }

  function setPrice(uint256 _newPriceE30) external {
    priceE30 = _newPriceE30;
  }

  function setMarketStatus(uint8 _newStatus) external {
    marketStatus = _newStatus;
  }

  function setPriceStale(bool _isPriceStale) external {
    isPriceStale = _isPriceStale;
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  // todo: validate price stale here
  function getLatestPrice(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidentTreshold */,
    uint256 /* _trustPriceAge */
  ) external view returns (uint256, uint256) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    return (priceE30, lastUpdate);
  }

  // todo: validate price stale here
  function getLatestPriceWithMarketStatus(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidenceThreshold */,
    uint256 /* _trustPriceAge */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    return (priceE30, lastUpdate, marketStatus);
  }

  function unsafeGetLatestPrice(
    bytes32 _assetId,
    bool /* _isMax */,
    uint256 /* _confidentTreshold */
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate);
    return (p.priceE30, p.lastUpdate);
  }

  function unsafeGetLatestPriceWithMarketStatus(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidenceThreshold */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    return (priceE30, lastUpdate, marketStatus);
  }

  function getLatestMarketPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold,
    uint256 _trustPriceAge,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate) {}

  function unsafeGetLatestMarketPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold,
    uint256 _trustPriceAge,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate) {}

  function getLatestMarketPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold,
    uint256 _trustPriceAge,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {}

  function unsafeGetLatestMarketPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold,
    uint256 _trustPriceAge,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {}
}
