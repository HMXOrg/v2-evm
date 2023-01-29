// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title ChainId - A library for getting the current chain id.
library ChainId {
  /// @dev Gets the current chain ID
  /// @return chainId The current chain ID
  function get() internal view returns (uint256 chainId) {
    assembly {
      chainId := chainid()
    }
  }
}
