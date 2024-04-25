// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITradeServiceHook {
  /**
   * Functions
   */
  function onIncreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    uint256 marketIndex,
    uint256 sizeDelta,
    bytes32 data
  ) external;

  function onDecreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    uint256 marketIndex,
    uint256 sizeDelta,
    bytes32 data
  ) external;

  function setWhitelistedCallers(address[] calldata _callers, bool[] calldata _isWhitelisteds) external;
}
