// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Types } from "@hmx/interfaces/gmx-v2/IGmxV2Types.sol";

interface IGmxV2WithdrawalCallbackReceiver {
  function afterWithdrawalExecution(
    bytes32 _key,
    IGmxV2Types.WithdrawalProps memory _props,
    IGmxV2Types.EventLogData memory _eventData
  ) external;

  function afterWithdrawalCancellation(
    bytes32 _key,
    IGmxV2Types.WithdrawalProps memory _props,
    IGmxV2Types.EventLogData memory _eventData
  ) external;
}
