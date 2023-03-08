// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";

contract MockOracleMiddleware is IOracleMiddleware {
  struct AssetPriceConfig {
    uint32 confidenceThresholdE6;
    uint8 trustPriceAge;
  }

  uint256 public priceE30;
  uint256 public lastUpdate;
  uint8 public mockMarketStatus;
  bool public isPriceStale;
  int32 public exponent;

  struct Price {
    uint256 priceE30;
    uint256 lastUpdate;
    uint256 marketStatus;
  }

  mapping(bytes32 => Price) price;

  mapping(bytes32 => bytes32) pythAssetId;

  mapping(address => bool) public isUpdater;
  mapping(bytes32 => AssetPriceConfig) public assetPriceConfigs;

  mapping(bytes32 => uint8) public marketStatus;

  constructor() {
    priceE30 = 1e30;
    lastUpdate = block.timestamp;
    mockMarketStatus = 2;
    exponent = -18;
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
    mockMarketStatus = _newStatus;
  }

  function setPriceStale(bool _isPriceStale) external {
    isPriceStale = _isPriceStale;
  }

  function setPythAssetId(bytes32 _pythAsset, bytes32 _pythId) external {
    pythAssetId[_pythAsset] = _pythId;
  }

  function setExponent(int32 _exponent) external {
    exponent = _exponent;
  }

  // =========================================
  // | ---------- Getter ------------------- |
  // =========================================

  // todo: validate price stale here
  function getLatestPrice(bytes32 _assetId, bool /* _isMax */) external view returns (uint256, uint256) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate);
    return (p.priceE30, p.lastUpdate);
  }

  // todo: validate price stale here
  function getLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool /* _isMax */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate, mockMarketStatus);
    return (p.priceE30, p.lastUpdate, mockMarketStatus);
  }

  function unsafeGetLatestPrice(
    bytes32 _assetId,
    bool /* _isMax */
  ) external view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate) {
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, exponent, lastUpdate);
    return (p.priceE30, exponent, p.lastUpdate);
  }

  function unsafeGetLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool /* _isMax */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate, mockMarketStatus);
    return (p.priceE30, p.lastUpdate, mockMarketStatus);
  }

  function getLatestAdaptivePrice(
    bytes32 _assetId,
    bool,
    int256,
    int256,
    uint256
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate);
    return (p.priceE30, p.lastUpdate);
  }

  function unsafeGetLatestAdaptivePrice(
    bytes32 _assetId,
    bool,
    int256,
    int256,
    uint256
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate);
    return (p.priceE30, p.lastUpdate);
  }

  function getLatestAdaptivePriceWithMarketStatus(
    bytes32 _assetId,
    bool,
    int256,
    int256,
    uint256
  ) external view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate, uint8 _status) {
    if (isPriceStale) revert IOracleMiddleware_PythPriceStale();
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, exponent, lastUpdate, mockMarketStatus);
    return (p.priceE30, exponent, p.lastUpdate, mockMarketStatus);
  }

  function unsafeGetLatestAdaptivePriceWithMarketStatus(
    bytes32 _assetId,
    bool,
    int256,
    int256,
    uint256
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    Price memory p = price[_assetId];
    if (p.priceE30 == 0) return (priceE30, lastUpdate, mockMarketStatus);
    return (p.priceE30, p.lastUpdate, mockMarketStatus);
  }

  function isSameAssetIdOnPyth(bytes32 _assetId1, bytes32 _assetId2) external view returns (bool) {
    return pythAssetId[_assetId1] == pythAssetId[_assetId2];
  }

  function setMarketStatus(bytes32 /*_assetId*/, uint8 /*_status*/) external {}

  function setUpdater(address /*_updater*/, bool /*_isActive*/) external {}

  function setAssetPriceConfig(
    bytes32 /*_assetId*/,
    uint32 /*_confidenceThresholdE6*/,
    uint8 _trustPriceAge
  ) external {}
}
