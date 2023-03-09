// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "@hmx/base/Owned.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "./interfaces/IOracleMiddleware.sol";

import { console2 } from "forge-std/console2.sol";

contract OracleMiddleware is Owned, IOracleMiddleware {
  /**
   * Structs
   */
  struct AssetPriceConfig {
    uint256 trustPriceAge;
    uint32 confidenceThresholdE6;
  }

  /**
   * Events
   */
  event LogSetMarketStatus(bytes32 indexed _assetId, uint8 _status);
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogSetAssetPriceConfig(
    bytes32 indexed _assetId,
    uint32 _oldConfidenceThresholdE6,
    uint32 _newConfidenceThresholdE6,
    uint256 _oldTrustPriceAge,
    uint256 _newTrustPriceAge
  );

  /**
   * States
   */
  IOracleAdapter public pythAdapter;

  // whitelist mapping of market status updater
  mapping(address => bool) public isUpdater;
  mapping(bytes32 => AssetPriceConfig) public assetPriceConfigs;

  // states
  // MarketStatus
  // Note from Pyth doc: Only prices with a value of status=trading should be used. If the status is not trading but is
  // Unknown, Halted or Auction the Pyth price can be an arbitrary value.
  // https://docs.pyth.network/design-overview/account-structure
  //
  // 0 = Undefined, default state since contract init
  // 1 = Inactive, equivalent to `unknown`, `halted`, `auction`, `ignored` from Pyth
  // 2 = Active, equivalent to `trading` from Pyth
  // assetId => marketStatus
  mapping(bytes32 => uint8) public marketStatus;

  constructor(IOracleAdapter _pythAdapter) {
    pythAdapter = _pythAdapter;
  }

  /**
   * Modifiers
   */

  modifier onlyUpdater() {
    if (!isUpdater[msg.sender]) {
      revert IOracleMiddleware_OnlyUpdater();
    }
    _;
  }

  /// @notice Return the latest price and last update of the given asset id.
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// @dev The currency of the price that will be quoted with depends on asset id. For example, we can have two BTC price but quoted differently.
  ///      In that case, we can define two different asset ids as BTC/USD, BTC/EUR.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  function getLatestPrice(bytes32 _assetId, bool _isMax) external view returns (uint256 _price, uint256 _lastUpdate) {
    (_price, , _lastUpdate) = _getLatestPrice(_assetId, _isMax);

    return (_price, _lastUpdate);
  }

  /// @notice Return the latest price and last update of the given asset id.
  /// @dev Same as getLatestPrice(), but unsafe function has no check price age
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// @dev The currency of the price that will be quoted with depends on asset id. For example, we can have two BTC price but quoted differently.
  ///      In that case, we can define two different asset ids as BTC/USD, BTC/EUR.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  function unsafeGetLatestPrice(
    bytes32 _assetId,
    bool _isMax
  ) external view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate) {
    (_price, _exponent, _lastUpdate) = _unsafeGetLatestPrice(_assetId, _isMax);

    return (_price, _exponent, _lastUpdate);
  }

  /// @notice Return the latest price of asset, last update of the given asset id, along with market status.
  /// @dev Same as getLatestPrice(), but with market status. Revert if status is 0 (Undefined) which means we never utilize this assetId.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  function getLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    _status = marketStatus[_assetId];
    if (_status == 0) revert IOracleMiddleware_MarketStatusUndefined();

    (_price, , _lastUpdate) = _getLatestPrice(_assetId, _isMax);

    return (_price, _lastUpdate, _status);
  }

  /// @notice Return the latest price of asset, last update of the given asset id, along with market status.
  /// @dev Same as unsafeGetLatestPrice(), but with market status. Revert if status is 0 (Undefined) which means we never utilize this assetId.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  function unsafeGetLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    _status = marketStatus[_assetId];
    if (_status == 0) revert IOracleMiddleware_MarketStatusUndefined();

    (_price, , _lastUpdate) = _unsafeGetLatestPrice(_assetId, _isMax);

    return (_price, _lastUpdate, _status);
  }

  /// @notice Return the latest adaptive rice of asset, last update of the given asset id
  /// @dev Adaptive price is the price that is applied with premium or discount based on the market skew.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _marketSkew market skew quoted in asset (NOT USD)
  /// @param _sizeDelta The size delta of this operation. It will determine the new market skew to be used for calculation.
  /// @param _maxSkewScaleUSD The config of maxSkewScaleUSD
  function getLatestAdaptivePrice(
    bytes32 _assetId,
    bool _isMax,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    (_price, , _lastUpdate) = _getLatestAdaptivePrice(
      _assetId,
      _isMax,
      _marketSkew,
      _sizeDelta,
      _maxSkewScaleUSD,
      true
    );
    return (_price, _lastUpdate);
  }

  /// @notice Return the unsafe latest adaptive rice of asset, last update of the given asset id
  /// @dev Adaptive price is the price that is applied with premium or discount based on the market skew.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _marketSkew market skew quoted in asset (NOT USD)
  /// @param _sizeDelta The size delta of this operation. It will determine the new market skew to be used for calculation.
  /// @param _maxSkewScaleUSD The config of maxSkewScaleUSD
  function unsafeGetLatestAdaptivePrice(
    bytes32 _assetId,
    bool _isMax,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    (_price, , _lastUpdate) = _getLatestAdaptivePrice(
      _assetId,
      _isMax,
      _marketSkew,
      _sizeDelta,
      _maxSkewScaleUSD,
      false
    );
    return (_price, _lastUpdate);
  }

  /// @notice Return the latest adaptive rice of asset, last update of the given asset id, along with market status.
  /// @dev Adaptive price is the price that is applied with premium or discount based on the market skew.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _marketSkew market skew quoted in asset (NOT USD)
  /// @param _sizeDelta The size delta of this operation. It will determine the new market skew to be used for calculation.
  /// @param _maxSkewScaleUSD The config of maxSkewScaleUSD
  function getLatestAdaptivePriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate, uint8 _status) {
    _status = marketStatus[_assetId];
    if (_status == 0) revert IOracleMiddleware_MarketStatusUndefined();

    (_price, _exponent, _lastUpdate) = _getLatestAdaptivePrice(
      _assetId,
      _isMax,
      _marketSkew,
      _sizeDelta,
      _maxSkewScaleUSD,
      true
    );
    return (_price, _exponent, _lastUpdate, _status);
  }

  /// @notice Return the latest adaptive rice of asset, last update of the given asset id, along with market status.
  /// @dev Adaptive price is the price that is applied with premium or discount based on the market skew.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _marketSkew market skew quoted in asset (NOT USD)
  /// @param _sizeDelta The size delta of this operation. It will determine the new market skew to be used for calculation.
  /// @param _maxSkewScaleUSD The config of maxSkewScaleUSD
  function unsafeGetLatestAdaptivePriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    _status = marketStatus[_assetId];
    if (_status == 0) revert IOracleMiddleware_MarketStatusUndefined();

    (_price, , _lastUpdate) = _getLatestAdaptivePrice(
      _assetId,
      _isMax,
      _marketSkew,
      _sizeDelta,
      _maxSkewScaleUSD,
      false
    );
    return (_price, _lastUpdate, _status);
  }

  function _getLatestPrice(
    bytes32 _assetId,
    bool _isMax
  ) private view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate) {
    AssetPriceConfig memory _assetConfig = assetPriceConfigs[_assetId];

    // 1. get price from Pyth
    (_price, _exponent, _lastUpdate) = pythAdapter.getLatestPrice(_assetId, _isMax, _assetConfig.confidenceThresholdE6);

    console2.log("_price", _price);
    console2.log("_exponent", _price);
    console2.log("_lastUpdate", _lastUpdate);
    console2.log("block.timestamp", block.timestamp);
    console2.log("_assetConfig.trustPriceAge", _assetConfig.trustPriceAge);
    // check price age
    if (block.timestamp - _lastUpdate > _assetConfig.trustPriceAge) revert IOracleMiddleware_PythPriceStale();

    // 2. Return the price and last update
    return (_price, _exponent, _lastUpdate);
  }

  function _unsafeGetLatestPrice(
    bytes32 _assetId,
    bool _isMax
  ) private view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate) {
    AssetPriceConfig memory _assetConfig = assetPriceConfigs[_assetId];

    // 1. get price from Pyth
    (_price, _exponent, _lastUpdate) = pythAdapter.getLatestPrice(_assetId, _isMax, _assetConfig.confidenceThresholdE6);

    // 2. Return the price and last update
    return (_price, _exponent, _lastUpdate);
  }

  function _getLatestAdaptivePrice(
    bytes32 _assetId,
    bool _isMax,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD,
    bool isSafe
  ) private view returns (uint256 _price, int32 _exponent, uint256 _lastUpdate) {
    // Get price from Pyth
    (_price, _exponent, _lastUpdate) = isSafe
      ? _getLatestPrice(_assetId, _isMax)
      : _unsafeGetLatestPrice(_assetId, _isMax);

    // Apply premium/discount
    _price = _calculateAdaptivePrice(_price, _exponent, _marketSkew, _sizeDelta, _maxSkewScaleUSD);

    // Return the price and last update
    return (_price, _exponent, _lastUpdate);
  }

  function _calculateAdaptivePrice(
    uint256 _price,
    int32 _exponent,
    int256 _marketSkew,
    int256 _sizeDelta,
    uint256 _maxSkewScaleUSD
  ) internal pure returns (uint256) {
    // Formula
    // marketSkew = longOpenInterest - shortOpenInterest
    // marketSkewUSD = marketSkew * price
    // premiumDiscountBefore = marketSkewUSD / maxSkewScaleUSD
    // premiumDiscountAfter = (marketSkewUSD + sizeDelta) / maxSkewScaleUSD
    // priceBefore = price + (price * premiumDiscountBefore)
    // priceAfter = price + (price * premiumDiscountAfter)
    // adaptivePrice = (priceBefore + priceAfter) / 2
    //
    // Example
    // price            = $1200 USD (oracle)
    // size             = 100
    // markerSkew       = 0
    // maxSkewScaleUSD  = $1,000,000
    //
    // Then,
    //
    // premiumDiscountBefore = 0 / 1,000,000
    //           = 0
    // premiumDiscountAfter  = (0 + 100) / 1,000,000
    //           = 100 / 1,000,000
    //           = 0.0001
    //
    // priceBefore = 1200 * (1 + premiumDiscountBefore)
    //              = 1200 * (1 + 0)
    //              = 1200
    // priceAfter  = 1200 * (1 + premiumDiscountAfter)
    //              = 1200 * (1 + 0.0001)
    //              = 1200 * (1.0001)
    //              = 1200.12
    // Finally,
    //
    // adaptivePrice = (priceBefore + priceAfter) / 2
    //            = (1200 + 1200.12) / 2
    //            = 1200.06
    int256 _priceInt = int256(_price);
    int256 _marketSkewUSD = (_marketSkew * _priceInt) / int256(10 ** uint32(-_exponent));

    int256 _premiumDiscountBefore = _maxSkewScaleUSD > 0
      ? (_marketSkewUSD * 1e30) / int256(_maxSkewScaleUSD)
      : int256(0);
    int256 _premiumDiscountAfter = _maxSkewScaleUSD > 0
      ? ((_marketSkewUSD + _sizeDelta) * 1e30) / int256(_maxSkewScaleUSD)
      : int256(0);

    int256 _priceBefore = _priceInt + ((_priceInt * _premiumDiscountBefore) / 1e30);
    int256 _priceAfter = _priceInt + ((_priceInt * _premiumDiscountAfter) / 1e30);
    int256 _adaptivePrice = (_priceBefore + _priceAfter) / 2;
    return _adaptivePrice > 0 ? uint256(_adaptivePrice) : 0;
  }

  /// @notice Set asset price configs
  /// @param _assetId Asset's to set price config
  /// @param _confidenceThresholdE6 New price confidence threshold
  /// @param _trustPriceAge valid price age
  function setAssetPriceConfig(
    bytes32 _assetId,
    uint32 _confidenceThresholdE6,
    uint256 _trustPriceAge
  ) external onlyOwner {
    AssetPriceConfig memory _config = assetPriceConfigs[_assetId];

    emit LogSetAssetPriceConfig(
      _assetId,
      _config.confidenceThresholdE6,
      _confidenceThresholdE6,
      _config.trustPriceAge,
      _trustPriceAge
    );
    _config.confidenceThresholdE6 = _confidenceThresholdE6;
    _config.trustPriceAge = _trustPriceAge;

    assetPriceConfigs[_assetId] = _config;
  }

  /// @notice Set market status for the given asset.
  /// @param _assetId The asset address to set.
  /// @param _status Status enum, see `marketStatus` comment section.
  function setMarketStatus(bytes32 _assetId, uint8 _status) external onlyUpdater {
    if (_status > 2) revert IOracleMiddleware_InvalidMarketStatus();

    marketStatus[_assetId] = _status;
    emit LogSetMarketStatus(_assetId, _status);
  }

  /// @notice A function for setting updater who is able to setMarketStatus
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    isUpdater[_account] = _isActive;
    emit LogSetUpdater(_account, _isActive);
  }
}
