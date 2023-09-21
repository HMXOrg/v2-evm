// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

contract WstEthUsdPriceAdapter is IPriceAdapter {
  error BadDecimals();

  AggregatorV3Interface public wstEthEthPriceFeed;
  AggregatorV3Interface public ethUsdPriceFeed;

  constructor(AggregatorV3Interface wstEthEthPriceFeed_, AggregatorV3Interface ethUsdPriceFeed_) {
    wstEthEthPriceFeed = wstEthEthPriceFeed_;
    ethUsdPriceFeed = ethUsdPriceFeed_;

    if (wstEthEthPriceFeed.decimals() != 18 && ethUsdPriceFeed.decimals() != 8) revert BadDecimals();
  }

  /// @notice Return the price of wstETH/USD in 18 decimals
  function getPrice() external view returns (uint256 price) {
    (, int256 wstEthEthPrice, , , ) = wstEthEthPriceFeed.latestRoundData();
    (, int256 ethUsdPrice, , , ) = ethUsdPriceFeed.latestRoundData();
    price = (uint256(wstEthEthPrice) * (uint256(ethUsdPrice) * 1e10)) / 1e18;
  }
}
