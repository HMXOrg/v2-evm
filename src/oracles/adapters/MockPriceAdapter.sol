// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";

contract MockPriceAdapter is IPriceAdapter {
  uint256 public price;

  constructor(uint256 initialPrice) {
    price = initialPrice;
  }

  /// @notice Return the price of GLP in 18 decimals
  function getPrice() external view returns (uint256 _price) {
    return price;
  }
}
