// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IOracleMiddleware } from "../../src/oracle/interfaces/IOracleMiddleware.sol";

contract MockOracleMiddleware is IOracleMiddleware {
  uint256 priceE30;
  uint256 lastUpdate;
  uint8 marketStatus;

  constructor() {
    priceE30 = 1e30;
    lastUpdate = block.timestamp;
    marketStatus = 2;
  }

  function getLatestPrice(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidentTreshold */
  ) external view returns (uint256, uint256) {
    return (priceE30, lastUpdate);
  }

  function getLatestPriceWithMarketStatus(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidenceThreshold */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    return (priceE30, lastUpdate, marketStatus);
  }
}
