// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

interface IOracleAdapter {
  function pyth() external returns (IPyth);

  function getLatestPrice(
    bytes32 _assetId,
    bool _isMax,
    uint32 _confidenceThreshold
  ) external view returns (uint256, int32, uint256);

  function setPythPriceId(bytes32 _assetId, bytes32 _pythPriceId) external;
}
