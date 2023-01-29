// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {OracleAdapterInterface} from "../interfaces/OracleAdapterInterface.sol";

contract OracleMiddleware is Owned, OracleAdapterInterface {
  // state variables
  mapping(bytes32 => OracleAdapterInterface) public oracleOf;

  // events
  event SetOracle(
    bytes32 asset,
    OracleAdapterInterface prevOracle,
    OracleAdapterInterface oracle
  );

  /// @notice Set the oracle for the given token.
  /// @param assetId The asset ID to map with the downstream oracle adapter.
  /// @param newOracle The oracle address to set.
  function setOracle(bytes32 assetId, OracleAdapterInterface newOracle)
    external
    onlyOwner
  {
    emit SetOracle(assetId, oracleOf[assetId], newOracle);
    oracleOf[assetId] = newOracle;
  }

  /// @notice Return the latest price in USD and last update of the given asset.
  /// @dev It is expected that the downstream contract should return the price in USD with 30 decimals.
  /// @param asset The asset id to get the price. This can be address or generic id.
  function getLatestPrice(bytes32 asset)
    external
    view
    returns (uint256, uint256)
  {
    return oracleOf[asset].getLatestPrice(asset);
  }
}
