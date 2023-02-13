// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage {
  // GLOBAL Parameter Configs
  // Liquidity
  uint256 depositFeeRate; // PLP deposit fee rate
  uint256 withdrawFeeRate; // PLP withdraw fee rate
  uint256 maxPLPUtilization;
  uint256 plpSafetyBufferThreshold;
  uint256 taxFee; // PLP deposit, withdraw, settle collect when pool weight is imbalances
  uint256 dynamicFeeEnabled; // if disabled, swap, add or remove liquidity will exclude tax fee ??
  uint256 flashLoanFeeRate;

  // Swap
  uint256 stablecoinSwapFee;
  uint256 swapFee;

  // Trading
  uint256 fundingInterval; // funding interval unit in seconds
  uint256 borrowingDevFeeRate;

  // Liquidation
  uint256 liquidationFee;

  MarketConfig[] marketConfigs;

  mapping(address => IConfigStorage.PLPTokenConfig) plpTokenConfigs; // token => config
  mapping(address => IConfigStorage.CollateralTokenConfig) colalteralTokenConfigs; // token => config

  mapping(address => bool) allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) serviceExecutors; // to allowed executor for service layer
}
