// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface OracleAdapterInterface {
  function getLatestPrice(bytes32 asset)
    external
    view
    returns (uint256, uint256);
}
