// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {OracleAdapterInterface} from "../interfaces/OracleAdapterInterface.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

contract OracleMiddleware is Owned {
  // errors
  error OracleMiddleware_PythPriceStale();

  // configs
  IPyth public pyth;
  OracleAdapterInterface public chainlinkAdapter;
  OracleAdapterInterface public pythAdapter;

  constructor(
    IPyth _pyth,
    OracleAdapterInterface _chainlinkAdapter,
    OracleAdapterInterface _pythAdapter
  ) {
    pyth = _pyth;
    chainlinkAdapter = _chainlinkAdapter;
    pythAdapter = _pythAdapter;
  }

  /// @notice Return the latest price in USD and last update of the given asset.
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// Due to the nature of Pyth oracle, the price can be staled without getting updates for a long time.
  /// Hence, get latest price should fallback to Chainlink oracle to allow getter functions to work as expected.
  /// @param asset The asset id to get the price. This can be address or generic id.
  /// @param isMax Whether to get the max price or min price.
  /// @param isStrict Whether to get the strict price or not. If strict, Oracle Middleware will revert when Pyth's price stale.
  function getLatestPrice(bytes32 asset, bool isMax, bool isStrict)
    external
    view
    returns (uint256, uint256)
  {
    // 1. get price from Pyth
    (uint256 price, uint256 lastUpdate) =
      pythAdapter.getLatestPrice(asset, isMax);
    // 2. if price is stale, get price from Chainlink to allow getter functions to work as expected
    if (block.timestamp - lastUpdate > pyth.getValidTimePeriod()) {
      // revert if strict
      if (isStrict) revert OracleMiddleware_PythPriceStale();
      // get price from Chainlink instead as fallback
      (price, lastUpdate) = chainlinkAdapter.getLatestPrice(asset, isMax);
    }
    // 3. Return the price and last update
    return (price, lastUpdate);
  }
}
