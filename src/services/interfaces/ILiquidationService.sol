// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidationService {
  error ILiquidationService_AccountHealthy();

  function liquidate(address subAccount) external;
}
