// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Config as ArbiConfig } from "../arbi-mainnet/Config.sol";

/// @dev This is just for make remappings not read
/// When we run tests, this will remapped to the correct Config.sol depends on the network
contract Config is ArbiConfig {

}
