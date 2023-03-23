// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITradeServiceHook {
  /**
   * Errors
   */

  /**
   * Core Functions
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
}
