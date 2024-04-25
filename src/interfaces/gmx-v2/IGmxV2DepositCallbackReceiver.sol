// SPDX-Licsense-Identifier: MIT
pragma solidity 0.8.18;

import { IGmxV2Types } from "@hmx/interfaces/gmx-v2/IGmxV2Types.sol";

interface IGmxV2DepositCallbackReceiver {
  function afterDepositExecution(
    bytes32 _key,
    IGmxV2Types.DepositProps memory _props,
    IGmxV2Types.EventLogData memory _eventData
  ) external;

  function afterDepositCancellation(
    bytes32 _key,
    IGmxV2Types.DepositProps memory _props,
    IGmxV2Types.EventLogData memory _eventData
  ) external;
}
