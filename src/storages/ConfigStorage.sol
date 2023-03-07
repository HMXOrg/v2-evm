// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// @todo - convert to upgradable
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { AddressUtils } from "../libraries/AddressUtils.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { Owned } from "../base/Owned.sol";
import { IteratableAddressList } from "../libraries/IteratableAddressList.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage, Owned {
  using AddressUtils for address;
  using IteratableAddressList for IteratableAddressList.List;
  using SafeERC20 for ERC20;
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

  mapping(address => bool) public allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) public serviceExecutors; // service => handler => isOK, to allowed executor for service layer

  address public feeCalculator;
  address public calculator;
  address public oracle;
  address public plp;
  address public treasury;
  uint32 public pnlFactorBPS; // factor that calculate unrealized PnL after collateral factor
  address public weth;

  /**
   * New States
   */

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
  address[] public tradeServiceHooks;

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

  function getTradeServiceHooks() external view returns (address[] memory) {
    return tradeServiceHooks;
  }

  /**
   * Setter
   */

  function setPlpAssetId(bytes32[] memory _plpAssetIds) external {
    plpAssetIds = _plpAssetIds;
  }

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

  function setPLPTotalTokenWeight(uint256 _totalTokenWeight) external {
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

  function setPnlFactor(uint32 _pnlFactor) external onlyOwner {
    pnlFactorBPS = _pnlFactor;
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
    assetPlpTokenConfigs[tokenAssetIds[_token]] = _newConfig;

    return _newConfig;
  }

  function setCollateralTokenConfig(
    bytes32 _assetId,
    CollateralTokenConfig memory _newConfig
  ) external returns (CollateralTokenConfig memory _collateralTokenConfig) {
    assetCollateralTokenConfigs[_assetId] = _newConfig;
    collateralAssetIds.push(_assetId);
    return assetCollateralTokenConfigs[_assetId];
  }

  function setAssetConfig(
    bytes32 assetId,
    AssetConfig memory _newConfig
  ) external returns (AssetConfig memory _assetConfig) {
    assetConfigs[assetId] = _newConfig;
    address _token = _newConfig.tokenAddress;

    if (_token != address(0)) {
      tokenAssetIds[_token] = assetId;

      // sanity check
      ERC20(_token).decimals();
    }

    return assetConfigs[assetId];
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
    return _newMarketIndex;
  }

  function delistMarket(uint256 _marketIndex) external {
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

  function setTradeServiceHooks(address[] calldata _newHooks) external onlyOwner {
    tradeServiceHooks = _newHooks;
  }
}
