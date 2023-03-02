// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// @todo - convert to upgradable

import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { Owned } from "../base/Owned.sol";
import { IteratableAddressList } from "../libraries/IteratableAddressList.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage, Owned {
  using AddressUtils for address;
  using IteratableAddressList for IteratableAddressList.List;

  /**
   * Events
   */
  event SetServiceExecutor(address indexed _contractAddress, address _executorAddress, bool _isServiceExecutor);

  event SetCalculator(address _calculator);
  event SetFeeCalculator(address _feeCalculator);
  event SetPLP(address _plp);
  event SetLiquidityConfig(LiquidityConfig _liquidityConfig);
  event SetDynamicEnabled(bool enabled);
  event AddOrUpdatePLPTokenConfigs(address _token, PLPTokenConfig _config, PLPTokenConfig _newConfig);
  event RemoveUnderlying(address _token);

  /**
   * Constants
   */
  address public constant ITERABLE_ADDRESS_LIST_START = address(1);
  address public constant ITERABLE_ADDRESS_LIST_END = address(1);

  /**
   * States
   */
  LiquidityConfig public liquidityConfig;
  SwapConfig public swapConfig;
  TradingConfig public tradingConfig;
  LiquidationConfig public liquidationConfig;

  MarketConfig[] public marketConfigs;
  AssetClassConfig[] public assetClassConfigs;

  // @todo discuss List or Array
  IteratableAddressList.List public plpAcceptedTokens;
  address[] public plpTokens;

  mapping(bytes32 => uint256) public marketConfigIndices; // assetId => index
  mapping(address => PLPTokenConfig) public plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) public collateralTokenConfigs; // token => config
  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) public serviceExecutors; // service => handler => isOK, to allowed executor for service layer

  address public feeCalculator;
  address public calculator;
  address public oracle;
  address public plp;
  address public treasury;
  uint256 public pnlFactor; // factor that calculate unrealized PnL after collateral factor
  address public weth;

  constructor() {
    plpAcceptedTokens.init();
  }

  /**
   * Validation
   */

  /// @notice Validate only whitelisted executor contracts to be able to call Service contracts.
  /// @param _contractAddress Service contract address to be executed.
  /// @param _executorAddress Executor contract address to call service contract.
  function validateServiceExecutor(address _contractAddress, address _executorAddress) external view {
    if (!serviceExecutors[_contractAddress][_executorAddress]) revert IConfigStorage_NotWhiteListed();
  }

  function validateAcceptedLiquidityToken(address _token) external view {
    if (!plpTokenConfigs[_token].accepted) revert IConfigStorage_NotAcceptedLiquidity();
  }

  /// @notice Validate only accepted token to be deposit/withdraw as collateral token.
  /// @param _token Token address to be deposit/withdraw.
  function validateAcceptedCollateral(address _token) external view {
    if (!collateralTokenConfigs[_token].accepted) revert IConfigStorage_NotAcceptedCollateral();
  }

  /**
   * Getter
   */

  function getMarketConfigById(uint256 _marketIndex) external view returns (MarketConfig memory _marketConfig) {
    return marketConfigs[_marketIndex];
  }

  function getTradingConfig() external view returns (TradingConfig memory) {
    return tradingConfig;
  }

  function getMarketConfigByIndex(uint256 _index) external view returns (MarketConfig memory _marketConfig) {
    return marketConfigs[_index];
  }

  function getAssetClassConfigByIndex(
    uint256 _index
  ) external view returns (AssetClassConfig memory _assetClassConfig) {
    return assetClassConfigs[_index];
  }

  function getPlpTokenConfigs(address _token) external view returns (PLPTokenConfig memory _plpTokenConfig) {
    return plpTokenConfigs[_token];
  }

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory _collateralTokenConfig) {
    return collateralTokenConfigs[_token];
  }

  function getPLPTokenConfig(address token) external view returns (PLPTokenConfig memory) {
    return plpTokenConfigs[token];
  }

  function getLiquidityConfig() external view returns (LiquidityConfig memory) {
    return liquidityConfig;
  }

  function getLiquidationConfig() external view returns (LiquidationConfig memory) {
    return liquidationConfig;
  }

  function getMarketConfigsLength() external view returns (uint256) {
    return marketConfigs.length;
  }

  function getMarketConfigByToken(address _token) external view returns (MarketConfig memory marketConfig) {
    for (uint i; i < marketConfigs.length; ) {
      if (marketConfigs[i].assetId == _token.toBytes32()) return marketConfigs[i];

      unchecked {
        i++;
      }
    }
  }

  function getPlpTokens() external view returns (address[] memory) {
    return plpTokens;
  }

  /// @notice Return the next underlying token address.
  /// @dev This uses to traverse all underlying tokens.
  /// @param token The token address to query the next token. Can also be START and END.
  function getNextAcceptedToken(address token) external view returns (address) {
    return plpAcceptedTokens.getNextOf(token);
  }

  /**
   * Setter
   */
  function setCalculator(address _calculator) external {
    calculator = _calculator;
    emit SetCalculator(calculator);
  }

  /// @notice Updates the fee calculator contract address.
  /// @dev This function can be used to set the address of the fee calculator contract.
  /// @param _feeCalculator The address of the new fee calculator contract.
  function setFeeCalculator(address _feeCalculator) external {
    feeCalculator = _feeCalculator;
    emit SetFeeCalculator(_feeCalculator);
  }

  function setOracle(address _oracle) external {
    // @todo - sanity check
    oracle = _oracle;
  }

  function setPLP(address _plp) external {
    plp = _plp;
    emit SetPLP(plp);
  }

  function setLiquidityConfig(LiquidityConfig memory _liquidityConfig) external {
    liquidityConfig = _liquidityConfig;
    emit SetLiquidityConfig(liquidityConfig);
  }

  function setDynamicEnabled(bool enabled) external {
    liquidityConfig.dynamicFeeEnabled = enabled;
    emit SetDynamicEnabled(enabled);
  }

  function setPLPTotalTokenWeight(uint32 _totalTokenWeight) external {
    if (_totalTokenWeight > 1e18) revert IConfigStorage_ExceedLimitSetting();
    liquidityConfig.plpTotalTokenWeight = _totalTokenWeight;
  }

  // @todo - Add Description
  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) external onlyOwner {
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;

    emit SetServiceExecutor(_contractAddress, _executorAddress, _isServiceExecutor);
  }

  function setPnlFactor(uint256 _pnlFactor) external onlyOwner {
    pnlFactor = _pnlFactor;
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

  function setMarketConfig(
    uint256 _marketIndex,
    MarketConfig memory _newConfig
  ) external returns (MarketConfig memory _marketConfig) {
    marketConfigs[_marketIndex] = _newConfig;
    return marketConfigs[_marketIndex];
  }

  function setPlpTokenConfig(
    address _token,
    PLPTokenConfig memory _newConfig
  ) external returns (PLPTokenConfig memory _plpTokenConfig) {
    plpTokenConfigs[_token] = _newConfig;
    plpTokens.push(_token);
    return plpTokenConfigs[_token];
  }

  function setCollateralTokenConfig(
    address _token,
    CollateralTokenConfig memory _newConfig
  ) external returns (CollateralTokenConfig memory _collateralTokenConfig) {
    collateralTokenConfigs[_token] = _newConfig;
    return collateralTokenConfigs[_token];
  }

  function setWeth(address _weth) external {
    weth = _weth;
  }

  /// @notice add or update AcceptedToken
  /// @dev This function only allows to add new token or update existing token,
  /// any attempt to remove token will be reverted.
  /// @param _tokens The token addresses to set.
  /// @param _configs The token configs to set.
  function addOrUpdateAcceptedToken(address[] calldata _tokens, PLPTokenConfig[] calldata _configs) external onlyOwner {
    if (_tokens.length != _configs.length) {
      revert IConfigStorage_BadLen();
    }

    for (uint256 i; i < _tokens.length; ) {
      // Enforce that isAccept must be true to prevent
      // removing underlying token through this function.
      if (!_configs[i].accepted) revert IConfigStorage_BadArgs();

      // If plpTokenConfigs.accepted is previously false,
      // then it is a new token to be added.
      if (!plpTokenConfigs[_tokens[i]].accepted) {
        plpAcceptedTokens.add(_tokens[i]);
        plpTokens.push(_tokens[i]);
      }

      // Log
      emit AddOrUpdatePLPTokenConfigs(_tokens[i], plpTokenConfigs[_tokens[i]], _configs[i]);

      // Update totalWeight accordingly

      if (liquidityConfig.plpTotalTokenWeight == 0) {
        liquidityConfig.plpTotalTokenWeight = _configs[i].targetWeight;
      } else {
        liquidityConfig.plpTotalTokenWeight =
          (liquidityConfig.plpTotalTokenWeight - plpTokenConfigs[_tokens[i]].targetWeight) +
          _configs[i].targetWeight;
      }

      plpTokenConfigs[_tokens[i]] = _configs[i];

      if (liquidityConfig.plpTotalTokenWeight > 1e18) {
        revert IConfigStorage_ExceedLimitSetting();
      }

      unchecked {
        ++i;
      }
    }
  }

  function addAssetClassConfig(AssetClassConfig calldata _newConfig) external returns (uint256 _index) {
    uint256 _newAssetClassIndex = assetClassConfigs.length;
    assetClassConfigs.push(_newConfig);
    return _newAssetClassIndex;
  }

  function setAssetClassConfigByIndex(uint256 _index, AssetClassConfig calldata _newConfig) external {
    assetClassConfigs[_index] = _newConfig;
  }

  function addMarketConfig(MarketConfig calldata _newConfig) external returns (uint256 _index) {
    uint256 _newMarketIndex = marketConfigs.length;
    marketConfigs.push(_newConfig);
    // update marketConfigIndices with new market index
    marketConfigIndices[_newConfig.assetId] = _newMarketIndex;
    return _newMarketIndex;
  }

  function delistMarket(uint256 _marketIndex) external {
    delete marketConfigs[_marketIndex].active;
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
}
