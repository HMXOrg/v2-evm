// SPDX-License-Identifier: MIT
//   _   _ __  ____  __
//  | | | |  \/  \ \/ /
//  | |_| | |\/| |\  /
//  |  _  | |  | |/  \
//  |_| |_|_|  |_/_/\_\
//

pragma solidity 0.8.18;

import { IPyth, PythStructs, IPythEvents } from "pyth-sdk-solidity/IPyth.sol";

interface IReadablePyth {
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
}
