// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

library HMXLib {
  function getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // Code below taken from https://github.com/Vectorized/solady/blob/1371af4f6ba483bc547723b2c2a887c2f941ace1/src/utils/FixedPointMathLib.sol
  /// @dev Returns the maximum of `x` and `y`.
  function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      z := xor(x, mul(xor(x, y), gt(y, x)))
    }
  }

  /// @dev Returns the maximum of `x` and `y`.
  function max(int256 x, int256 y) internal pure returns (int256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      z := xor(x, mul(xor(x, y), sgt(y, x)))
    }
  }

  /// @dev Returns the minimum of `x` and `y`.
  function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      z := xor(x, mul(xor(x, y), lt(y, x)))
    }
  }

  /// @dev Returns the minimum of `x` and `y`.
  function min(int256 x, int256 y) internal pure returns (int256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      z := xor(x, mul(xor(x, y), slt(y, x)))
    }
  }

  /// @dev Returns the absolute value of `x`.
  function abs(int256 x) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      let mask := sub(0, shr(255, x))
      z := xor(mask, add(mask, x))
    }
  }

  /// @notice Derive positionId from sub-account and market index
  function getPositionId(address _subAccount, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
