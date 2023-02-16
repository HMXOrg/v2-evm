// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage {
  using AddressUtils for address;

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

  //events
  event SetServiceExecutor(address _service, address _handler, bool _isOk);
  event SetCalculator(address _calculator);
  event SetPLP(address _plp);
  event SetLiquidityConfig(LiquidityConfig _liquidityConfig);
  event SetDynamicEnabled(bool enabled);

  // methods
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

  function getPLPTokenConfig(
    address token
  ) external view returns (PLPTokenConfig memory) {
    return plpTokenConfigs[token];
  }

  function getLiquidityConfig() external view returns (LiquidityConfig memory) {
    return liquidityConfig;
  }

  function getLiquidationConfig()
    external
    view
    returns (LiquidationConfig memory)
  {
    return liquidationConfig;
  }

  function getMarketConfigsLength() external view returns (uint256) {
    return marketConfigs.length;
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

  function setCalculator(address _calculator) external {
    calculator = _calculator;
    emit SetCalculator(calculator);
  }

  function setPLP(address _plp) external {
    plp = _plp;
    emit SetPLP(calculator);
  }

  function setLiquidityConfig(
    LiquidityConfig memory _liquidityConfig
  ) external {
    liquidityConfig = _liquidityConfig;
    emit SetLiquidityConfig(liquidityConfig);
  }

  function setDynamicEnabled(bool enabled) external {
    liquidityConfig.dynamicFeeEnabled = enabled;
    emit SetDynamicEnabled(enabled);
  }

  function setPLPTotalTokenWeight(uint256 _totalTokenWeight) external {
    if (_totalTokenWeight > 1e18) revert ConfigStorage_ExceedLimitSetting();
    plpTotalTokenWeight = _totalTokenWeight;
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

  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) external {
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;
  }

  function validateServiceExecutor(
    address contractAddress,
    address executorAddress
  ) external view {
    if (!serviceExecutors[contractAddress][executorAddress])
      revert ConfigStorage_NotWhiteListed();
  }
}
