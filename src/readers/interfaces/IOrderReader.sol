// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";

interface IOrderReader {
  function getExecutableOrders(
    uint64 _limit,
    uint64 _offset,
    uint64[] memory _prices,
    bool[] memory _shouldInverts
  ) external view returns (ILimitTradeHandler.LimitOrder[] memory);
}
