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

  // TODO refactor move to struct?
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
  function setServiceExecutor(
    address contractAddress,
    address executorAddress,
    bool isServiceExecutor
  ) external {
    serviceExecutors[contractAddress][executorAddress] = isServiceExecutor;
    emit SetServiceExecutor(
      contractAddress,
      executorAddress,
      isServiceExecutor
    );
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

  function validateServiceExecutor(
    address contractAddress,
    address executorAddress
  ) external view {
    if (!serviceExecutors[contractAddress][executorAddress])
      revert ConfigStorage_NotWhiteListed();
  }
}
