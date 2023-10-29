// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Types } from "@hmx/interfaces/gmx-v2/IGmxV2Types.sol";

interface IGmxV2Reader {
  function getMarketTokenPrice(
    address dataStore,
    IGmxV2Types.MarketProps memory market,
    IGmxV2Types.PriceProps memory indexTokenPrice,
    IGmxV2Types.PriceProps memory longTokenPrice,
    IGmxV2Types.PriceProps memory shortTokenPrice,
    bytes32 pnlFactorType,
    bool maximize
  ) external view returns (int256, IGmxV2Types.MarketPoolValueInfoProps memory);
}
