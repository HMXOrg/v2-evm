// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Market } from "@hmx/interfaces/gmxV2/Market.sol";
import { Price } from "@hmx/interfaces/gmxV2/Price.sol";
import { MarketPoolValueInfo } from "@hmx/interfaces/gmxV2/MarketPoolValueInfo.sol";
import { IGmxV2Reader } from "@hmx/interfaces/gmxV2/IGmxV2Reader.sol";

contract MockGmxV2Reader is IGmxV2Reader {
  mapping(address marketAddress => uint256 price) public prices;

  function setPrice(address marketToken, uint256 priceE30) external {
    prices[marketToken] = priceE30;
  }

  function getMarketTokenPrice(
    address dataStore,
    Market.Props memory market,
    Price.Props memory indexTokenPrice,
    Price.Props memory longTokenPrice,
    Price.Props memory shortTokenPrice,
    bytes32 pnlFactorType,
    bool maximize
  ) external view returns (int256 marketTokenPrice, MarketPoolValueInfo.Props memory props) {
    marketTokenPrice = int256(prices[market.marketToken]);
  }
}
