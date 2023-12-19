// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ICalcPriceAdapter } from "@hmx/oracles/interfaces/ICalcPriceAdapter.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

contract MockGmPriceAdapter is ICalcPriceAdapter {
  uint256 public fixedPrice;

  constructor(uint256 initialPrice) {
    fixedPrice = initialPrice;
  }

  /// @notice Return the price of GM Market Token in 18 decimals
  function getPrice(IEcoPythCalldataBuilder3.BuildData[] calldata _buildDatas) external view returns (uint256 price) {
    price = fixedPrice;
  }

  /// @notice Return the price of GM Market Token in 18 decimals
  function getPrice(uint256[] memory priceE8s) external view returns (uint256 price) {
    price = fixedPrice;
  }
}
