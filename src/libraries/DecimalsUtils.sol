// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library DecimalsUtils {
  /// @notice Convert decimals of a value
  /// @param value The value to convert
  /// @param fromDecimals The decimals of the value
  /// @param toDecimals The decimals to convert to
  function convertDecimals(uint256 value, uint8 fromDecimals, uint8 toDecimals)
    internal
    pure
    returns (uint256)
  {
    return value * (10 ** uint256(toDecimals)) / (10 ** uint256(fromDecimals));
  }
}
