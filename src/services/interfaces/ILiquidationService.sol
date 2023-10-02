// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidationService {
  /**
   * Errors
   */
  error ILiquidationService_AccountHealthy();
  error ILiquidationService_InvalidAddress();

  /**
   * Functions
   */
  function reloadConfig() external;

  function liquidate(address subAccount, address _liquidator) external;

  function perpStorage() external view returns (address);

  function vaultStorage() external view returns (address);
}
