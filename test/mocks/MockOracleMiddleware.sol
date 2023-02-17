// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IOracleMiddleware } from "../../src/oracle/interfaces/IOracleMiddleware.sol";

contract MockOracleMiddleware is IOracleMiddleware {
  uint256 public priceE30;
  uint256 public lastUpdate;
  uint8 public marketStatus;

  constructor() {
    priceE30 = 1e30;
    lastUpdate = block.timestamp;
    marketStatus = 2;
  }

  function setMarketStatus(uint8 _newStatus) external {
    marketStatus = _newStatus;
  }

  function setPrice(uint256 _newPriceE30) external {
    priceE30 = _newPriceE30;
  }

  // todo: validate price stale here
  function getLatestPrice(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidentTreshold */,
    uint256 /* _trustPriceAge */
  ) external view returns (uint256, uint256) {
    return (priceE30, lastUpdate);
  }

  // todo: validate price stale here
  function getLatestPriceWithMarketStatus(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidenceThreshold */,
    uint256 /* _trustPriceAge */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    return (priceE30, lastUpdate, marketStatus);
  }

  function unsafeGetLatestPrice(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidentTreshold */
  ) external view returns (uint256 _price, uint256 _lastUpdate) {
    return (priceE30, lastUpdate);
  }

  function unsafeGetLatestPriceWithMarketStatus(
    bytes32 /* _assetId */,
    bool /* _isMax */,
    uint256 /* _confidenceThreshold */
  ) external view returns (uint256 _price, uint256 _lastUpdate, uint8 _status) {
    return (priceE30, lastUpdate, marketStatus);
  }
}
