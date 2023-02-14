// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage {
  // GLOBAL Configs
  LiquidityConfig public liquidityConfig;
  SwapConfig public swapConfig;
  TrandingConfig public trandingConfig;
  LiquidationConfig public liquidationConfig;
  MarketConfig[] public marketConfigs;

  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config

  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  // service => handler => isOK
  mapping(address => mapping(address => bool)) public serviceExecutors; // to allowed executor for service layer

  // ERRORs
  event SetServiceExecutor(
    address indexed contractAddress,
    address _xecutorAddress,
    bool isServiceExecutor
  );

  constructor() {}

  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) public {
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;

    emit SetServiceExecutor(
      _contractAddress,
      _executorAddress,
      _isServiceExecutor
    );
  }

  function validateServiceExecutor(
    address _contractAddress,
    address _executorAddress
  ) public view {
    if (!serviceExecutors[_contractAddress][_executorAddress])
      revert NotWhiteListed();
  }

  function validateAcceptedCollateral(address _token) public view {
    if (!collateralTokenConfigs[_token].accepted)
      revert NotAcceptedCollateral();
  }
}
