// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth, PythStructs, IPythEvents } from "pyth-sdk-solidity/IPyth.sol";

interface IReadablePyth {
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
}
