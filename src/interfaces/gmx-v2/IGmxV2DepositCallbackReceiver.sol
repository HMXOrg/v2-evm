// SPDX-Licsense-Identifier: MIT
pragma solidity ^0.8.0;

import { Deposit } from "@hmx/interfaces/gmx-v2/Deposit.sol";
import { EventUtils } from "@hmx/interfaces/gmx-v2/EventUtils.sol";

// @title IDepositCallbackReceiver
// @dev interface for a deposit callback contract
interface IGmxV2DepositCallbackReceiver {
  // @dev called after a deposit execution
  // @param key the key of the deposit
  // @param deposit the deposit that was executed
  function afterDepositExecution(
    bytes32 key,
    Deposit.Props memory deposit,
    EventUtils.EventLogData memory eventData
  ) external;

  // @dev called after a deposit cancellation
  // @param key the key of the deposit
  // @param deposit the deposit that was cancelled
  function afterDepositCancellation(
    bytes32 key,
    Deposit.Props memory deposit,
    EventUtils.EventLogData memory eventData
  ) external;
}
