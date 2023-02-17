// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IteratableAddressList } from "../libraries/IteratableAddressList.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage, Ownable {
  using AddressUtils for address;
  using IteratableAddressList for IteratableAddressList.List;

  address public constant ITERABLE_ADDRESS_LIST_START = address(1);
  address public constant ITERABLE_ADDRESS_LIST_END = address(1);

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

  IteratableAddressList.List public plpAcceptedTokens;

  //events
  event SetServiceExecutor(address _service, address _handler, bool _isOk);
  event SetCalculator(address _calculator);
  event SetPLP(address _plp);
  event SetLiquidityConfig(LiquidityConfig _liquidityConfig);
  event SetDynamicEnabled(bool enabled);
  event AddOrUpdatePLPTokenConfigs(
    address _token,
    PLPTokenConfig _config,
    PLPTokenConfig _newConfig
  );
  event RemoveUnderlying(address _token);

  constructor() {
    plpAcceptedTokens.init();
  }

  // getter functions
  function getMarketConfigById(
    uint256 _marketIndex
  ) external view returns (MarketConfig memory) {
    return marketConfigs[_marketIndex];
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

  /// @notice Return the next underlying token address.
  /// @dev This uses to traverse all underlying tokens.
  /// @param token The token address to query the next token. Can also be START and END.
  function getNextAcceptedToken(address token) external view returns (address) {
    return plpAcceptedTokens.getNextOf(token);
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
    liquidityConfig.plpTotalTokenWeight = _totalTokenWeight;
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

  function delistMarket(uint256 _marketIndex) external {
    delete marketConfigs[_marketIndex].active;
  }

  function setMarketConfig(
    uint256 _marketIndex,
    MarketConfig memory _newConfig
  ) external returns (MarketConfig memory) {
    marketConfigs[_marketIndex] = _newConfig;
    return marketConfigs[_marketIndex];
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

  /// @notice add or update AcceptedToken
  /// @dev This function only allows to add new token or update existing token,
  /// any atetempt to remove token will be reverted.
  /// @param _tokens The token addresses to set.
  /// @param _configs The token configs to set.
  function addorUpdateAcceptedToken(
    address[] calldata _tokens,
    PLPTokenConfig[] calldata _configs
  ) external onlyOwner {
    if (_tokens.length != _configs.length) {
      revert ConfigStorage_BadLen();
    }

    for (uint256 i = 0; i < _tokens.length; ) {
      // Enforce that isAccept must be true to prevent
      // removing underlying token through this function.
      if (!_configs[i].accepted) revert ConfigStorage_BadArgs();

      // If plpTokenConfigs.accepted is previously false,
      // then it is a new token to be added.
      if (!plpTokenConfigs[_tokens[i]].accepted) {
        plpAcceptedTokens.add(_tokens[i]);
      }

      // Log
      emit AddOrUpdatePLPTokenConfigs(
        _tokens[i],
        plpTokenConfigs[_tokens[i]],
        _configs[i]
      );

      // Update totalWeight accordingly
      liquidityConfig.plpTotalTokenWeight =
        (liquidityConfig.plpTotalTokenWeight -
          plpTokenConfigs[_tokens[i]].targetWeight) +
        _configs[i].targetWeight;
      plpTokenConfigs[_tokens[i]] = _configs[i];

      if (liquidityConfig.plpTotalTokenWeight > 1e18) {
        revert ConfigStorage_ExceedLimitSetting();
      }

      unchecked {
        ++i;
      }
    }
  }

  /// @notice Remove underlying token.
  /// @param _token The token address to remove.
  function removeAcceptedToken(address _token) external onlyOwner {
    // Update totalTokenWeight
    liquidityConfig.plpTotalTokenWeight -= plpTokenConfigs[_token].targetWeight;

    // Delete token from plpAcceptedTokens list
    plpAcceptedTokens.remove(_token, plpAcceptedTokens.getPreviousOf(_token));

    // Delete plpTokenConfig
    delete plpTokenConfigs[_token];

    emit RemoveUnderlying(_token);
  }

  function validateServiceExecutor(
    address contractAddress,
    address executorAddress
  ) external view {
    if (!serviceExecutors[contractAddress][executorAddress])
      revert ConfigStorage_NotWhiteListed();
  }
}
