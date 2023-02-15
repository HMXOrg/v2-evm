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
  TradingConfig public tradingConfig;
  LiquidationConfig public liquidationConfig;
  MarketConfig[] public marketConfigs;
  mapping(bytes32 => uint256) public marketConfigIndices; // assetId => index

  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config

  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  // service => handler => isOK
  mapping(address => mapping(address => bool)) public serviceExecutors; // to allowed executor for service layer

  uint256 public pnlFactor; // factor that calculate unrealized PnL after collateral factor

  address public calculator;
  address public plp;
  address public treasury;
  uint256 public plpTotalTokenWeight;

  // getter functions
  function getMarketConfigs(
    uint256 _marketId
  ) external view returns (MarketConfig memory) {
    return marketConfigs[_marketId];
  }

  function getPlpTokenConfigs(
    address _token
  ) external view returns (PLPTokenConfig memory) {
    return plpTokenConfigs[_token];
  }

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory) {
    return collateralTokenConfigs[_token];
  }

  // setter functions
  function addMarketConfig(
    MarketConfig calldata _newConfig
  ) external returns (MarketConfig memory) {
    marketConfigs.push(_newConfig);
    uint256 _newMarketId = marketConfigs.length;
    // update marketConfigIndices with new market id
    marketConfigIndices[_newConfig.assetId] = _newMarketId;
    // index = id - 1;
    return marketConfigs[_newMarketId - 1];
  }

  function setMarketConfig(
    uint256 _marketId,
    MarketConfig memory _newConfig
  ) external returns (MarketConfig memory) {
    marketConfigs[_marketId] = _newConfig;
    return marketConfigs[_marketId];
  }

  function setPlpTokenConfig(
    address _token,
    PLPTokenConfig memory _newConfig
  ) external returns (PLPTokenConfig memory) {
    plpTokenConfigs[_token] = _newConfig;
    return plpTokenConfigs[_token];
  }

  function setCollateralTokenConfig(
    address _token,
    CollateralTokenConfig memory _newConfig
  ) external returns (CollateralTokenConfig memory) {
    collateralTokenConfigs[_token] = _newConfig;
    return collateralTokenConfigs[_token];
  }
}
