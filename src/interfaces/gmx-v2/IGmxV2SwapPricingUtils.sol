// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxV2SwapPricingUtils {
  struct Props {
    address marketToken;
    address indexToken;
    address longToken;
    address shortToken;
  }

  struct GetPriceImpactUsdParams {
    address dataStore;
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
