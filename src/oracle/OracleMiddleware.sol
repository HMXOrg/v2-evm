// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "./interfaces/IOracleMiddleware.sol";

contract OracleMiddleware is Owned, IOracleMiddleware {
  // errors
  error OracleMiddleware_PythPriceStale();
  error OracleMiddleware_MarketStatusUndefined();
  error OracleMiddleware_OnlyUpdater();
  error OracleMiddleware_InvalidMarketStatus();

  // configs
  IOracleAdapter public pythAdapter;

  // whitelist mapping of market status updater
  mapping(address => bool) public isUpdater;

  // events
  event SetMarketStatus(bytes32 indexed _assetId, uint8 _status);
  event SetUpdater(address indexed _account, bool _isActive);

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

  modifier onlyUpdater() {
    if (!isUpdater[msg.sender]) {
      revert OracleMiddleware_OnlyUpdater();
    }
    _;
  }

  /// @notice Set market status for the given asset.
  /// @param _assetId The asset address to set.
  /// @param _status Status enum, see `marketStatus` comment section.
  function setMarketStatus(
    bytes32 _assetId,
    uint8 _status
  ) external onlyUpdater {
    if (_status > 2) revert OracleMiddleware_InvalidMarketStatus();

    marketStatus[_assetId] = _status;
    emit SetMarketStatus(_assetId, _status);
  }

  /// @notice A function for setting updater who is able to setMarketStatus
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    isUpdater[_account] = _isActive;
    emit SetUpdater(_account, _isActive);
  }

  /// @notice Return the latest price in USD and last update of the given asset.
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _confidenceThreshold The threshold in which use to validate the price confidence. Input 1 ether to ignore the check.
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold
  ) external view returns (uint256, uint256) {
    return _getLatestPrice(_assetId, _isMax, _confidenceThreshold);
  }

  function _getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold
  ) internal view returns (uint256 _price, uint256 _lastUpdate) {
    // 1. get price from Pyth
    (_price, _lastUpdate) = pythAdapter.getLatestPrice(
      _assetId,
      _isMax,
      _confidenceThreshold
    );

    // 2. Return the price and last update
    return (_price, _lastUpdate);
  }

  /// @notice Return the latest price in USD, last update of the given asset, along with market status.
  /// @dev Same as getLatestPrice(), but with market status. Revert if status is 0 (Undefined) which means we never utilize this assetId.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _confidenceThreshold The threshold in which use to validate the price confidence. Input 1 ether to ignore the check.
  function getLatestPriceWithMarketStatus(
    bytes32 _assetId,
    bool _isMax,
    uint256 _confidenceThreshold
  ) external view returns (uint256, uint256, uint8) {
    uint8 _status = marketStatus[_assetId];
    if (_status == 0) revert OracleMiddleware_MarketStatusUndefined();

    (uint256 _price, uint256 _lastUpdate) = _getLatestPrice(
      _assetId,
      _isMax,
      _confidenceThreshold
    );
    return (_price, _lastUpdate, _status);
  }
}
