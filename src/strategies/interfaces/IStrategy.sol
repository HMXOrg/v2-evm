// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

interface IStrategy {
  struct StakedGlpStrategyConfig {
    IGmxRewardRouterV2 rewardRouter;
    IGmxRewardTracker rewardTracker;
    IGmxGlpManager glpManager;
    IOracleMiddleware oracleMiddleware;
    IVaultStorage vaultStorage;
  }

  function execute() external;
}
