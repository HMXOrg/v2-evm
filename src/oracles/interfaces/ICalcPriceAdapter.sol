// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IEcoPythCalldataBuilder3 } from "./IEcoPythCalldataBuilder3.sol";

interface ICalcPriceAdapter {
  function getPrice(IEcoPythCalldataBuilder3.BuildData[] calldata _buildDatas) external view returns (uint256 price);
}
