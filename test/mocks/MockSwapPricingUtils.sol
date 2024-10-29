// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2SwapPricingUtils } from "@hmx/interfaces/gmx-v2/IGmxV2SwapPricingUtils.sol";

contract MockSwapPricingUtils is IGmxV2SwapPricingUtils {
  function getPriceImpactUsd(
    IGmxV2SwapPricingUtils.GetPriceImpactUsdParams memory params
  ) external view returns (int256) {
    return 0;
  }
}
