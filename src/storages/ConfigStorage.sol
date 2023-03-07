// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// @todo - convert to upgradable
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { IteratableAddressList } from "../libraries/IteratableAddressList.sol";

import { Owned } from "../base/Owned.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is ReentrancyGuard, IConfigStorage, Owned {
  using AddressUtils for address;
  using IteratableAddressList for IteratableAddressList.List;
  using SafeERC20 for ERC20;

  /**
   * Events
   */
  event SetServiceExecutor(address indexed contractAddress, address executorAddress, bool isServiceExecutor);
  event SetCalculator(address indexed oldCalculator, address newCalculator);
  event SetFeeCalculator(address indexed oldFeeCalculator, address newFeeCalculator);
  event SetOracle(address indexed oldOracle, address newOracle);
  event SetPLP(address indexed oldPlp, address newPlp);
  event SetLiquidityConfig(LiquidityConfig indexed oldLiquidityConfig, LiquidityConfig newLiquidityConfig);
  event SetDynamicEnabled(bool enabled);
  event SetPLPTotalTokenWeight(uint256 oldTotalTokenWeight, uint256 newTotalTokenWeight);
  event SetPnlFactor(uint32 oldPnlFactorBPS, uint32 newPnlFactorBPS);
  event SetSwapConfig(SwapConfig indexed oldConfig, SwapConfig newConfig);
  event SetTradingConfig(TradingConfig indexed oldConfig, TradingConfig newConfig);
  event SetLiquidationConfig(LiquidationConfig indexed oldConfig, LiquidationConfig newConfig);
  event SetMarketConfig(uint256 marketIndex, MarketConfig oldConfig, MarketConfig newConfig);
  event SetPlpTokenConfig(address token, PLPTokenConfig oldConfig, PLPTokenConfig newConfig);
  event SetCollateralTokenConfig(bytes32 assetId, CollateralTokenConfig oldConfig, CollateralTokenConfig newConfig);
  event SetAssetConfig(bytes32 assetId, AssetConfig oldConfig, AssetConfig newConfig);
  event SetWeth(address indexed oldWeth, address newWeth);
  event SetAssetClassConfigByIndex(uint256 index, AssetClassConfig oldConfig, AssetClassConfig newConfig);

  event AddOrUpdatePLPTokenConfigs(address token, PLPTokenConfig oldConfig, PLPTokenConfig newConfig);
  event AddAssetClassConfig(uint256 index, AssetClassConfig newConfig);
  event AddMarketConfig(uint256 index, MarketConfig newConfig);
  event RemoveUnderlying(address token);
  event DelistMarket(uint256 marketIndex);

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

  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) public serviceExecutors; // service => handler => isOK, to allowed executor for service layer

  address public feeCalculator;
  address public calculator;
  address public oracle;
  address public plp;
  address public treasury;
  uint32 public pnlFactorBPS; // factor that calculate unrealized PnL after collateral factor
  address public weth;

  // Token's address => Asset ID
  mapping(address => bytes32) public tokenAssetIds;
  // Pyth Asset ID => Configs
  mapping(bytes32 => AssetConfig) public assetConfigs;
  // PLP stuff
  bytes32[] public plpAssetIds;
  mapping(bytes32 => PLPTokenConfig) public assetPlpTokenConfigs;
  // Cross margin
  bytes32[] public collateralAssetIds;
  mapping(bytes32 => CollateralTokenConfig) public assetCollateralTokenConfigs;
  // Trade
  MarketConfig[] public marketConfigs;
  AssetClassConfig[] public assetClassConfigs;

  constructor() {}

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
    if (!assetPlpTokenConfigs[tokenAssetIds[_token]].accepted) revert IConfigStorage_NotAcceptedLiquidity();
  }

  /// @notice Validate only accepted token to be deposit/withdraw as collateral token.
  /// @param _token Token address to be deposit/withdraw.
  function validateAcceptedCollateral(address _token) external view {
    if (!assetCollateralTokenConfigs[tokenAssetIds[_token]].accepted) revert IConfigStorage_NotAcceptedCollateral();
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

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory _collateralTokenConfig) {
    return assetCollateralTokenConfigs[tokenAssetIds[_token]];
  }

  function getAssetTokenDecimal(address _token) external view returns (uint8) {
    return assetConfigs[tokenAssetIds[_token]].decimals;
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

  function getPlpTokens() external view returns (address[] memory) {
    address[] memory _result = new address[](plpAssetIds.length);

    for (uint256 _i = 0; _i < plpAssetIds.length; ) {
      _result[_i] = assetConfigs[plpAssetIds[_i]].tokenAddress;
      unchecked {
        ++_i;
      }
    }

    return _result;
  }

  function getAssetConfigByToken(address _token) external view returns (AssetConfig memory) {
    return assetConfigs[tokenAssetIds[_token]];
  }

  function getCollateralTokens() external view returns (address[] memory) {
    bytes32[] memory _collateralAssetIds = collateralAssetIds;
    mapping(bytes32 => AssetConfig) storage _assetConfigs = assetConfigs;

    uint256 _len = _collateralAssetIds.length;
    address[] memory tokenAddresses = new address[](_len);

    for (uint256 _i; _i < _len; ) {
      tokenAddresses[_i] = _assetConfigs[_collateralAssetIds[_i]].tokenAddress;

      unchecked {
        ++_i;
      }
    }
    return tokenAddresses;
  }

  function getAssetConfig(bytes32 _assetId) external view returns (AssetConfig memory) {
    return assetConfigs[_assetId];
  }

  function getAssetPlpTokenConfig(bytes32 _assetId) external view returns (PLPTokenConfig memory) {
    return assetPlpTokenConfigs[_assetId];
  }

  function getAssetPlpTokenConfigByToken(address _token) external view returns (PLPTokenConfig memory) {
    return assetPlpTokenConfigs[tokenAssetIds[_token]];
  }

  function getPlpAssetIds() external view returns (bytes32[] memory) {
    return plpAssetIds;
  }

  /**
   * Setter
   */

  function setPlpAssetId(bytes32[] memory _plpAssetIds) external onlyOwner {
    plpAssetIds = _plpAssetIds;
  }

  function setCalculator(address _calculator) external onlyOwner {
    emit SetCalculator(calculator, _calculator);
    // @todo - add sanity check
    calculator = _calculator;
  }

  /// @notice Updates the fee calculator contract address.
  /// @dev This function can be used to set the address of the fee calculator contract.
  /// @param _feeCalculator The address of the new fee calculator contract.
  function setFeeCalculator(address _feeCalculator) external onlyOwner {
    emit SetFeeCalculator(feeCalculator, _feeCalculator);
    // @todo - add sanity check
    feeCalculator = _feeCalculator;
  }

  function setOracle(address _oracle) external onlyOwner {
    emit SetOracle(oracle, _oracle);
    // @todo - sanity check
    oracle = _oracle;
  }

  function setPLP(address _plp) external onlyOwner {
    emit SetPLP(plp, _plp);
    // @todo - sanity check
    plp = _plp;
  }

  function setLiquidityConfig(LiquidityConfig memory _liquidityConfig) external onlyOwner {
    emit SetLiquidityConfig(liquidityConfig, _liquidityConfig);
    // @todo - sanity check
    liquidityConfig = _liquidityConfig;
  }

  function setDynamicEnabled(bool enabled) external onlyOwner {
    liquidityConfig.dynamicFeeEnabled = enabled;
    emit SetDynamicEnabled(enabled);
  }

  function setPLPTotalTokenWeight(uint256 _totalTokenWeight) external onlyOwner {
    if (_totalTokenWeight > 1e18) revert IConfigStorage_ExceedLimitSetting();
    emit SetPLPTotalTokenWeight(liquidityConfig.plpTotalTokenWeight, _totalTokenWeight);
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

  function setPnlFactor(uint32 _pnlFactorBPS) external onlyOwner {
    emit SetPnlFactor(pnlFactorBPS, _pnlFactorBPS);
    pnlFactorBPS = _pnlFactorBPS;
  }

  function setSwapConfig(SwapConfig memory _newConfig) external onlyOwner {
    emit SetSwapConfig(swapConfig, _newConfig);
    swapConfig = _newConfig;
  }

  function setTradingConfig(TradingConfig memory _newConfig) external onlyOwner {
    emit SetTradingConfig(tradingConfig, _newConfig);
    tradingConfig = _newConfig;
  }

  function setLiquidationConfig(LiquidationConfig memory _newConfig) external onlyOwner {
    emit SetLiquidationConfig(liquidationConfig, _newConfig);
    liquidationConfig = _newConfig;
  }

  function setMarketConfig(
    uint256 _marketIndex,
    MarketConfig memory _newConfig
  ) external onlyOwner returns (MarketConfig memory _marketConfig) {
    emit SetMarketConfig(_marketIndex, marketConfigs[_marketIndex], _newConfig);
    marketConfigs[_marketIndex] = _newConfig;
    return marketConfigs[_marketIndex];
  }

  function setPlpTokenConfig(
    address _token,
    PLPTokenConfig memory _newConfig
  ) external onlyOwner returns (PLPTokenConfig memory _plpTokenConfig) {
    emit SetPlpTokenConfig(_token, assetPlpTokenConfigs[tokenAssetIds[_token]], _newConfig);
    assetPlpTokenConfigs[tokenAssetIds[_token]] = _newConfig;
    return _newConfig;
  }

  function setCollateralTokenConfig(
    bytes32 _assetId,
    CollateralTokenConfig memory _newConfig
  ) external onlyOwner returns (CollateralTokenConfig memory _collateralTokenConfig) {
    emit SetCollateralTokenConfig(_assetId, assetCollateralTokenConfigs[_assetId], _newConfig);
    assetCollateralTokenConfigs[_assetId] = _newConfig;
    collateralAssetIds.push(_assetId);
    return assetCollateralTokenConfigs[_assetId];
  }

  function setAssetConfig(
    bytes32 _assetId,
    AssetConfig memory _newConfig
  ) external onlyOwner returns (AssetConfig memory _assetConfig) {
    emit SetAssetConfig(_assetId, assetConfigs[_assetId], _newConfig);
    assetConfigs[_assetId] = _newConfig;
    address _token = _newConfig.tokenAddress;

    if (_token != address(0)) {
      tokenAssetIds[_token] = _assetId;

      // sanity check
      ERC20(_token).decimals();
    }

    return assetConfigs[_assetId];
  }

  function setWeth(address _weth) external onlyOwner {
    emit SetWeth(weth, _weth);
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

    uint256 _len = _tokens.length;
    for (uint256 _i; _i < _len; ) {
      bytes32 _assetId = tokenAssetIds[_tokens[_i]];

      // Enforce that isAccept must be true to prevent
      // removing underlying token through this function.
      if (!_configs[_i].accepted) revert IConfigStorage_BadArgs();

      // If plpTokenConfigs.accepted is previously false,
      // then it is a new token to be added.
      if (!assetPlpTokenConfigs[_assetId].accepted) {
        plpAssetIds.push(_assetId);
      }
      // Log
      emit AddOrUpdatePLPTokenConfigs(_tokens[_i], assetPlpTokenConfigs[_assetId], _configs[_i]);

      // Update totalWeight accordingly

      liquidityConfig.plpTotalTokenWeight == 0 ? _configs[_i].targetWeight : liquidityConfig.plpTotalTokenWeight =
        (liquidityConfig.plpTotalTokenWeight - assetPlpTokenConfigs[_assetId].targetWeight) +
        _configs[_i].targetWeight;

      assetPlpTokenConfigs[_assetId] = _configs[_i];

      if (liquidityConfig.plpTotalTokenWeight > 1e18) {
        revert IConfigStorage_ExceedLimitSetting();
      }

      unchecked {
        ++_i;
      }
    }
  }

  function addAssetClassConfig(AssetClassConfig calldata _newConfig) external onlyOwner returns (uint256 _index) {
    uint256 _newAssetClassIndex = assetClassConfigs.length;
    assetClassConfigs.push(_newConfig);
    emit AddAssetClassConfig(_newAssetClassIndex, _newConfig);
    return _newAssetClassIndex;
  }

  function setAssetClassConfigByIndex(uint256 _index, AssetClassConfig calldata _newConfig) external onlyOwner {
    emit SetAssetClassConfigByIndex(_index, assetClassConfigs[_index], _newConfig);
    assetClassConfigs[_index] = _newConfig;
  }

  function addMarketConfig(MarketConfig calldata _newConfig) external onlyOwner returns (uint256 _index) {
    uint256 _newMarketIndex = marketConfigs.length;
    marketConfigs.push(_newConfig);
    emit AddMarketConfig(_newMarketIndex, _newConfig);
    return _newMarketIndex;
  }

  function delistMarket(uint256 _marketIndex) external onlyOwner {
    emit DelistMarket(_marketIndex);
    delete marketConfigs[_marketIndex].active;
  }

  /// @notice Remove underlying token.
  /// @param _token The token address to remove.
  function removeAcceptedToken(address _token) external onlyOwner {
    bytes32 _assetId = tokenAssetIds[_token];

    // Update totalTokenWeight
    liquidityConfig.plpTotalTokenWeight -= assetPlpTokenConfigs[_assetId].targetWeight;

    // delete from plpAssetIds
    uint256 _len = plpAssetIds.length;
    for (uint256 _i = 0; _i < _len; ) {
      if (_assetId == plpAssetIds[_i]) {
        delete plpAssetIds[_i];
        break;
      }

      unchecked {
        ++_i;
      }
    }
    // Delete plpTokenConfig
    delete assetPlpTokenConfigs[_assetId];

    emit RemoveUnderlying(_token);
  }
}
