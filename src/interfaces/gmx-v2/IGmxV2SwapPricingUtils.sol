// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { DataStore } from "@hmx/interfaces/gmx-v2/DataStore.sol";

interface IGmxV2SwapPricingUtils {
  struct Props {
    address marketToken;
    address indexToken;
    address longToken;
    address shortToken;
  }

  struct GetPriceImpactUsdParams {
    DataStore dataStore;
    Props market;
    address tokenA;
    address tokenB;
    uint256 priceForTokenA;
    uint256 priceForTokenB;
    int256 usdDeltaForTokenA;
    int256 usdDeltaForTokenB;
    bool includeVirtualInventoryImpact;
  }

  function getPriceImpactUsd(GetPriceImpactUsdParams memory params) external view returns (int256);
}
