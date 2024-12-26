// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Withdrawal } from "@hmx/interfaces/gmx-v2/Withdrawal.sol";
import { EventUtils } from "@hmx/interfaces/gmx-v2/EventUtils.sol";

// @title IGmxV2WithdrawalCallbackReceiver
// @dev interface for a withdrawal callback contract
interface IGmxV2WithdrawalCallbackReceiver {
  // @dev called after a withdrawal execution
  // @param key the key of the withdrawal
  // @param withdrawal the withdrawal that was executed
  function afterWithdrawalExecution(
    bytes32 key,
    Withdrawal.Props memory withdrawal,
    EventUtils.EventLogData memory eventData
  ) external;

  // @dev called after a withdrawal cancellation
  // @param key the key of the withdrawal
  // @param withdrawal the withdrawal that was cancelled
  function afterWithdrawalCancellation(
    bytes32 key,
    Withdrawal.Props memory withdrawal,
    EventUtils.EventLogData memory eventData
  ) external;
}
