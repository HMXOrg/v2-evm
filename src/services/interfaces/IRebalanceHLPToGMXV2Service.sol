// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGMXExchangeRouter } from "@hmx/interfaces/gmx/IGMXExchangeRouter.sol";

interface IRebalanceHLPToGMXV2Service {
  error RebalanceHLPToGMXV2Service_Unauthorized();
  error RebalanceHLPToGMXV2Service_KeyNotFound();
  error RebalanceHLPToGMXV2Service_ZeroMarketTokenReceived();
  error RebalanceHLPToGMXV2Service_AmountIsZero();

  struct DepositParams {
    address longToken;
    uint256 longTokenAmount;
    address shortToken;
    uint256 shortTokenAmount;
    IGMXExchangeRouter.CreateDepositParams params;
  }

  function executeDeposits(DepositParams[] calldata depositParams) external;

  function setMinHLPValueLossBPS(uint16 _hlpValueLossBPS) external;
}
