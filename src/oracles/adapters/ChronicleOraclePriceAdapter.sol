// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";
import { IChronicle } from "src/oracles/interfaces/IChronicle.sol";

contract ChronicleOraclePriceAdapter is IPriceAdapter {
  IChronicle public priceFeed;

  constructor(address priceFeed_) {
    priceFeed = IChronicle(priceFeed_);
  }

  /// @notice Return the price in 18 decimals
  function getPrice() external view returns (uint256 price) {
    price = priceFeed.read();
  }
}
