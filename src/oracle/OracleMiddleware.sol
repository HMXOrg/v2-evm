// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "./interfaces/IOracleMiddleware.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

contract OracleMiddleware is Owned, IOracleMiddleware {
  // errors
  error OracleMiddleware_PythPriceStale();

  // configs
  IPyth public pyth;
  IOracleAdapter public pythAdapter;

  constructor(IPyth _pyth, IOracleAdapter _pythAdapter) {
    pyth = _pyth;
    pythAdapter = _pythAdapter;
  }

  /// @notice Return the latest price in USD and last update of the given asset.
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// @param _assetId The asset id to get the price. This can be address or generic id.
  /// @param _isMax Whether to get the max price or min price.
  /// @param _confidenceThreshold The threshold in which use to validate the price confidence. Input 1 ether to ignore the check.
  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint8 _confidenceThreshold
  ) external view returns (uint256, uint256) {
    // 1. get price from Pyth
    (uint256 price, uint256 lastUpdate) = pythAdapter.getLatestPrice(
      _assetId,
      _isMax,
      _confidenceThreshold
    );

    // 2. Return the price and last update
    return (price, lastUpdate);
  }
}
