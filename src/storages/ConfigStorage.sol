// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// @todo - convert to upgradable
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

import { console } from "forge-std/console.sol"; //@todo - remove

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is Ownable, IConfigStorage {
  // using libs for type
  using AddressUtils for address;

  // CONFIGS
  LiquidityConfig public liquidityConfig;
  SwapConfig public swapConfig;
  TradingConfig public tradingConfig;
  LiquidationConfig public liquidationConfig;
  MarketConfig[] public marketConfigs;

  // STATES
  mapping(bytes32 => uint256) public marketConfigIndices; // assetId => index
  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config
  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) public serviceExecutors; // service => handler => isOK, to allowed executor for service layer
  uint256 public pnlFactor; // factor that calculate unrealized PnL after collateral factor

  address public calculator;
  address public plp;
  address public treasury;
  uint256 public plpTotalTokenWeight;

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

  function getMarketConfigByIndex(
    uint256 _index
  ) external view returns (MarketConfig memory marketConfig) {
    return marketConfigs[_index];
  }

  function getMarketConfigs(
    uint256 _marketId
  ) external view returns (MarketConfig memory) {
    return marketConfigs[_marketId];
  }

  function getMarketConfigById(
    bytes32 _assetId
  ) external view returns (MarketConfig memory) {
    uint256 _index = marketConfigIndices[_assetId];
    return marketConfigs[_index];
  }

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
  function setLiquidityConfig(LiquidityConfig memory _newConfig) external {
    liquidityConfig = _newConfig;
  }

  function setSwapConfig(SwapConfig memory _newConfig) external {
    swapConfig = _newConfig;
  }

  function setTradingConfig(TradingConfig memory _newConfig) external {
    tradingConfig = _newConfig;
  }

  function setLiquidationConfig(LiquidationConfig memory _newConfig) external {
    liquidationConfig = _newConfig;
  }

  function addMarketConfig(
    MarketConfig calldata _newConfig
  ) external returns (uint256 _index) {
    uint256 _newMarketIndex = marketConfigs.length;
    marketConfigs.push(_newConfig);
    // update marketConfigIndices with new market index
    marketConfigIndices[_newConfig.assetId] = _newMarketIndex;
    return _newMarketIndex;
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
