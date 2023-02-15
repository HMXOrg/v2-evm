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
  // assetId => index
  mapping(bytes32 => uint256) public marketConfigIndices;

  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config

  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  // service => handler => isOK
  mapping(address => mapping(address => bool)) public serviceExecutors; // to allowed executor for service layer

  uint256 public pnlFactor; // factor that calculate unrealized PnL after collateral factor

  // ERRORs
  event SetServiceExecutor(
    address indexed contractAddress,
    address _xecutorAddress,
    bool isServiceExecutor
  );

  constructor() {}

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  VALIDATION FUNCTION  ///////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function validateServiceExecutor(
    address _contractAddress,
    address _executorAddress
  ) external view {
    if (!serviceExecutors[_contractAddress][_executorAddress])
      revert NotWhiteListed();
  }

  function validateAcceptedCollateral(address _token) external view {
    if (!collateralTokenConfigs[_token].accepted)
      revert NotAcceptedCollateral();
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) external {
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;

    emit SetServiceExecutor(
      _contractAddress,
      _executorAddress,
      _isServiceExecutor
    );
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory collateralTokenConfig) {
    return collateralTokenConfigs[_token];
  }

  function getMarketConfigByIndex(
    uint256 _index
  ) external view returns (MarketConfig memory marketConfig) {
    return marketConfigs[_index];
  }

  function getMarketConfigByAssetId(
    bytes32 _assetId
  ) external view returns (MarketConfig memory marketConfig) {
    for (uint i; i < marketConfigs.length; ) {
      if (marketConfigs[i].assetId == _assetId) return marketConfigs[i];
      unchecked {
        i++;
      }
    }
  }

  function getMarketConfigById(
    bytes32 _assetId
  ) external view returns (MarketConfig memory) {
    uint256 _index = marketConfigIndices[_assetId];
    return marketConfigs[_index];
  }
}
