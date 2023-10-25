// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IGMXExchangeRouter } from "@hmx/interfaces/gmx-v2/IGMXExchangeRouter.sol";

interface IRebalanceHLPToGMXV2Service {
  error RebalanceHLPToGMXV2Service_Unauthorized();
  error RebalanceHLPToGMXV2Service_KeyNotFound();
  error RebalanceHLPToGMXV2Service_ZeroMarketTokenReceived();
  error RebalanceHLPToGMXV2Service_AmountIsZero();

  struct DepositParams {
    address market;
    address longToken;
    uint256 longTokenAmount;
    address shortToken;
    uint256 shortTokenAmount;
    uint256 minMarketTokens;
    uint256 executionFee;
  }

  function executeDeposits(DepositParams[] calldata depositParams) external;

  function setMinHLPValueLossBPS(uint16 _hlpValueLossBPS) external;
}
