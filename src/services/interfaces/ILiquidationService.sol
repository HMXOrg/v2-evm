// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidationService {
  error ILiquidationService_AccountHealthy();

  function reloadConfig() external;

  function liquidate(address subAccount) external;

  function perpStorage() external view returns (address);
}
