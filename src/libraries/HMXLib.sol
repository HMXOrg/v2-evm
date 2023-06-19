// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

library HMXLib {
  error HMXLib_WrongSubAccountId();

  function getSubAccount(address _primary, uint8 _subAccountId) internal pure returns (address _subAccount) {
    if (_subAccountId > 255) revert HMXLib_WrongSubAccountId();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function max(int256 a, int256 b) internal pure returns (int256) {
    return a > b ? a : b;
  }

  function min(int256 a, int256 b) internal pure returns (int256) {
    return a < b ? a : b;
  }

  function abs(int256 x) internal pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  /// @notice Derive positionId from sub-account and market index
  function getPositionId(address _subAccount, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_subAccount, _marketIndex));
  }
}
