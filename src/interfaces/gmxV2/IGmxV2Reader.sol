// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Market } from "./Market.sol";
import { Price } from "./Price.sol";
import { MarketPoolValueInfo } from "./MarketPoolValueInfo.sol";

interface IGmxV2Reader {
  function getMarketTokenPrice(
    address dataStore,
    Market.Props memory market,
    Price.Props memory indexTokenPrice,
    Price.Props memory longTokenPrice,
    Price.Props memory shortTokenPrice,
    bytes32 pnlFactorType,
    bool maximize
  ) external view returns (int256, MarketPoolValueInfo.Props memory);
}
