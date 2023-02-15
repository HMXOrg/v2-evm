// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// @todo - convert to upgradable
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is Ownable, IConfigStorage {
  // using libs for type
  using AddressUtils for address;

  // CONFIGS
  LiquidityConfig public liquidityConfig;
  SwapConfig public swapConfig;
  TrandingConfig public trandingConfig;
  LiquidationConfig public liquidationConfig;
  MarketConfig[] public marketConfigs;

  // STATES
  mapping(bytes32 => uint256) public marketConfigIndices; // assetId => index
  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config
  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) public serviceExecutors; // service => handler => isOK, to allowed executor for service layer
  uint256 public pnlFactor; // factor that calculate unrealized PnL after collateral factor

  // EVENTS
  event SetServiceExecutor(
    address indexed contractAddress,
    address _xecutorAddress,
    bool isServiceExecutor
  );

  constructor() {}

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  VALIDATION
  ////////////////////////////////////////////////////////////////////////////////////

  /// @notice Validate only whitelisted executor contracts to be able to call Service contracts.
  /// @param _contractAddress Service contract address to be executed.
  /// @param _executorAddress Executor contract address to call service contract.
  function validateServiceExecutor(
    address _contractAddress,
    address _executorAddress
  ) external view {
    if (!serviceExecutors[_contractAddress][_executorAddress])
      revert NotWhiteListed();
  }

  /// @notice Validate only accepted token to be deposit/withdraw as collateral token.
  /// @param _token Token address to be deposit/withdraw.
  function validateAcceptedCollateral(address _token) external view {
    if (!collateralTokenConfigs[_token].accepted)
      revert NotAcceptedCollateral();
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER
  ////////////////////////////////////////////////////////////////////////////////////

  // @todo - Add Description
  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) external onlyOwner {
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;

    emit SetServiceExecutor(
      _contractAddress,
      _executorAddress,
      _isServiceExecutor
    );
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER
  ////////////////////////////////////////////////////////////////////////////////////

  // @todo - Add Description
  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory collateralTokenConfig) {
    return collateralTokenConfigs[_token];
  }

  // @todo - Add Description
  function getMarketConfigByIndex(
    uint256 _index
  ) external view returns (MarketConfig memory marketConfig) {
    return marketConfigs[_index];
  }

  // @todo - Add Description
  function getMarketConfigByToken(
    address _token
  ) external view returns (MarketConfig memory marketConfig) {
    for (uint i; i < marketConfigs.length; ) {
      if (marketConfigs[i].assetId == _token.toBytes32())
        return marketConfigs[i];

      unchecked {
        i++;
      }
    }
  }

  // @todo - Add Description
  function getMarketConfigById(
    bytes32 _assetId
  ) external view returns (MarketConfig memory) {
    uint256 _index = marketConfigIndices[_assetId];
    return marketConfigs[_index];
  }
}
