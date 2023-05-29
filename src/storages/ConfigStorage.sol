// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracles/interfaces/IOracleMiddleware.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage, OwnableUpgradeable {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  /**
   * Events
   */
  event LogSetServiceExecutor(address indexed contractAddress, address executorAddress, bool isServiceExecutor);
  event LogSetCalculator(address indexed oldCalculator, address newCalculator);
  event LogSetOracle(address indexed oldOracle, address newOracle);
  event LogSetHLP(address indexed oldHlp, address newHlp);
  event LogSetLiquidityConfig(LiquidityConfig indexed oldLiquidityConfig, LiquidityConfig newLiquidityConfig);
  event LogSetDynamicEnabled(bool enabled);
  event LogSetPnlFactor(uint32 oldPnlFactorBPS, uint32 newPnlFactorBPS);
  event LogSetSwapConfig(SwapConfig indexed oldConfig, SwapConfig newConfig);
  event LogSetTradingConfig(TradingConfig indexed oldConfig, TradingConfig newConfig);
  event LogSetLiquidationConfig(LiquidationConfig indexed oldConfig, LiquidationConfig newConfig);
  event LogSetMarketConfig(uint256 marketIndex, MarketConfig oldConfig, MarketConfig newConfig);
  event LogSetHlpTokenConfig(address token, HLPTokenConfig oldConfig, HLPTokenConfig newConfig);
  event LogSetCollateralTokenConfig(bytes32 assetId, CollateralTokenConfig oldConfig, CollateralTokenConfig newConfig);
  event LogSetAssetConfig(bytes32 assetId, AssetConfig oldConfig, AssetConfig newConfig);
  event LogSetToken(address indexed oldToken, address newToken);
  event LogSetAssetClassConfigByIndex(uint256 index, AssetClassConfig oldConfig, AssetClassConfig newConfig);
  event LogSetLiquidityEnabled(bool oldValue, bool newValue);
  event LogSetMinimumPositionSize(uint256 oldValue, uint256 newValue);
  event LogSetConfigExecutor(address indexed executorAddress, bool isServiceExecutor);
  event LogAddAssetClassConfig(uint256 index, AssetClassConfig newConfig);
  event LogAddMarketConfig(uint256 index, MarketConfig newConfig);
  event LogRemoveUnderlying(address token);
  event LogDelistMarket(uint256 marketIndex);
  event LogAddOrUpdateHLPTokenConfigs(address _token, HLPTokenConfig _config, HLPTokenConfig _newConfig);

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

  address public calculator;
  address public oracle;
  address public hlp;
  address public treasury;
  uint32 public pnlFactorBPS; // factor that calculate unrealized PnL after collateral factor
  uint256 public minimumPositionSize;
  address public weth;
  address public sglp;

  // Token's address => Asset ID
  mapping(address => bytes32) public tokenAssetIds;
  // Asset ID => Configs
  mapping(bytes32 => AssetConfig) public assetConfigs;
  // HLP stuff
  bytes32[] public hlpAssetIds;
  mapping(bytes32 => HLPTokenConfig) public assetHlpTokenConfigs;
  // Cross margin
  bytes32[] public collateralAssetIds;
  mapping(bytes32 => CollateralTokenConfig) public assetCollateralTokenConfigs;
  // Trade
  MarketConfig[] public marketConfigs;
  AssetClassConfig[] public assetClassConfigs;
  address[] public tradeServiceHooks;

  mapping(address => bool) public configExecutors;

  /**
   * Modifiers
   */

  modifier onlyWhitelistedExecutor() {
    if (!configExecutors[msg.sender]) revert IConfigStorage_NotWhiteListed();
    _;
  }

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();
  }

  /**
   * Validations
   */
  /// @notice Validate only whitelisted executor contracts to be able to call Service contracts.
  /// @param _contractAddress Service contract address to be executed.
  /// @param _executorAddress Executor contract address to call service contract.
  function validateServiceExecutor(address _contractAddress, address _executorAddress) external view {
    if (!serviceExecutors[_contractAddress][_executorAddress]) revert IConfigStorage_NotWhiteListed();
  }

  function validateAcceptedLiquidityToken(address _token) external view {
    if (!assetHlpTokenConfigs[tokenAssetIds[_token]].accepted) revert IConfigStorage_NotAcceptedLiquidity();
  }

  /// @notice Validate only accepted token to be deposit/withdraw as collateral token.
  /// @param _token Token address to be deposit/withdraw.
  function validateAcceptedCollateral(address _token) external view {
    if (!assetCollateralTokenConfigs[tokenAssetIds[_token]].accepted) revert IConfigStorage_NotAcceptedCollateral();
  }

  /**
   * Getters
   */

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

  function getMarketConfigs() external view returns (MarketConfig[] memory) {
    return marketConfigs;
  }

  function getMarketConfigsLength() external view returns (uint256) {
    return marketConfigs.length;
  }

  function getAssetClassConfigsLength() external view returns (uint256) {
    return assetClassConfigs.length;
  }

  function getHlpTokens() external view returns (address[] memory) {
    address[] memory _result = new address[](hlpAssetIds.length);

    for (uint256 _i = 0; _i < hlpAssetIds.length; ) {
      _result[_i] = assetConfigs[hlpAssetIds[_i]].tokenAddress;
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

  function getAssetHlpTokenConfig(bytes32 _assetId) external view returns (HLPTokenConfig memory) {
    return assetHlpTokenConfigs[_assetId];
  }

  function getAssetHlpTokenConfigByToken(address _token) external view returns (HLPTokenConfig memory) {
    return assetHlpTokenConfigs[tokenAssetIds[_token]];
  }

  function getHlpAssetIds() external view returns (bytes32[] memory) {
    return hlpAssetIds;
  }

  function getTradeServiceHooks() external view returns (address[] memory) {
    return tradeServiceHooks;
  }

  /**
   * Setter
   */

  function setConfigExecutor(address _executorAddress, bool _isServiceExecutor) external onlyOwner {
    configExecutors[_executorAddress] = _isServiceExecutor;
    emit LogSetConfigExecutor(_executorAddress, _isServiceExecutor);
  }

  function setMinimumPositionSize(uint256 _minimumPositionSize) external onlyOwner {
    emit LogSetMinimumPositionSize(minimumPositionSize, _minimumPositionSize);
    minimumPositionSize = _minimumPositionSize;
  }

  function setHlpAssetId(bytes32[] memory _hlpAssetIds) external onlyOwner {
    hlpAssetIds = _hlpAssetIds;
  }

  function setCalculator(address _calculator) external onlyOwner {
    emit LogSetCalculator(calculator, _calculator);
    calculator = _calculator;

    // Sanity check
    ICalculator(_calculator).getPendingBorrowingFeeE30();
  }

  function setOracle(address _oracle) external onlyOwner {
    emit LogSetOracle(oracle, _oracle);
    oracle = _oracle;

    // Sanity check
    IOracleMiddleware(_oracle).isUpdater(_oracle);
  }

  function setHLP(address _hlp) external onlyOwner {
    if (_hlp == address(0)) revert IConfigStorage_InvalidAddress();
    emit LogSetHLP(hlp, _hlp);

    hlp = _hlp;
  }

  function setLiquidityConfig(LiquidityConfig memory _liquidityConfig) external onlyOwner {
    emit LogSetLiquidityConfig(liquidityConfig, _liquidityConfig);
    liquidityConfig = _liquidityConfig;
  }

  function setLiquidityEnabled(bool _enabled) external onlyWhitelistedExecutor {
    emit LogSetLiquidityEnabled(liquidityConfig.enabled, _enabled);
    liquidityConfig.enabled = _enabled;
  }

  function setDynamicEnabled(bool _enabled) external onlyWhitelistedExecutor {
    liquidityConfig.dynamicFeeEnabled = _enabled;
    emit LogSetDynamicEnabled(_enabled);
  }

  function setServiceExecutor(
    address _contractAddress,
    address _executorAddress,
    bool _isServiceExecutor
  ) external onlyOwner {
    if (_contractAddress == address(0) || _executorAddress == address(0)) revert IConfigStorage_InvalidAddress();
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;
    emit LogSetServiceExecutor(_contractAddress, _executorAddress, _isServiceExecutor);
  }

  function setPnlFactor(uint32 _pnlFactorBPS) external onlyOwner {
    emit LogSetPnlFactor(pnlFactorBPS, _pnlFactorBPS);
    pnlFactorBPS = _pnlFactorBPS;
  }

  function setSwapConfig(SwapConfig memory _newConfig) external onlyOwner {
    emit LogSetSwapConfig(swapConfig, _newConfig);
    swapConfig = _newConfig;
  }

  function setTradingConfig(TradingConfig memory _newConfig) external onlyOwner {
    emit LogSetTradingConfig(tradingConfig, _newConfig);
    tradingConfig = _newConfig;
  }

  function setLiquidationConfig(LiquidationConfig memory _newConfig) external onlyOwner {
    emit LogSetLiquidationConfig(liquidationConfig, _newConfig);
    liquidationConfig = _newConfig;
  }

  function setMarketConfig(
    uint256 _marketIndex,
    MarketConfig memory _newConfig
  ) external onlyOwner returns (MarketConfig memory _marketConfig) {
    emit LogSetMarketConfig(_marketIndex, marketConfigs[_marketIndex], _newConfig);
    marketConfigs[_marketIndex] = _newConfig;
    return marketConfigs[_marketIndex];
  }

  function setHlpTokenConfig(
    address _token,
    HLPTokenConfig memory _newConfig
  ) external onlyOwner returns (HLPTokenConfig memory _hlpTokenConfig) {
    emit LogSetHlpTokenConfig(_token, assetHlpTokenConfigs[tokenAssetIds[_token]], _newConfig);
    assetHlpTokenConfigs[tokenAssetIds[_token]] = _newConfig;
    return _newConfig;
  }

  function setCollateralTokenConfig(
    bytes32 _assetId,
    CollateralTokenConfig memory _newConfig
  ) external onlyOwner returns (CollateralTokenConfig memory _collateralTokenConfig) {
    emit LogSetCollateralTokenConfig(_assetId, assetCollateralTokenConfigs[_assetId], _newConfig);
    assetCollateralTokenConfigs[_assetId] = _newConfig;
    collateralAssetIds.push(_assetId);
    return assetCollateralTokenConfigs[_assetId];
  }

  function setAssetConfig(
    bytes32 _assetId,
    AssetConfig memory _newConfig
  ) external onlyOwner returns (AssetConfig memory _assetConfig) {
    emit LogSetAssetConfig(_assetId, assetConfigs[_assetId], _newConfig);
    assetConfigs[_assetId] = _newConfig;
    address _token = _newConfig.tokenAddress;

    if (_token != address(0)) {
      tokenAssetIds[_token] = _assetId;

      // sanity check
      ERC20Upgradeable(_token).decimals();
    }

    return assetConfigs[_assetId];
  }

  function setWeth(address _weth) external onlyOwner {
    emit LogSetToken(weth, _weth);
    weth = _weth;
  }

  function setSGlp(address _sglp) external onlyOwner {
    emit LogSetToken(sglp, _sglp);
    sglp = _sglp;
  }

  /// @notice add or update AcceptedToken
  /// @dev This function only allows to add new token or update existing token,
  /// any attempt to remove token will be reverted.
  /// @param _tokens The token addresses to set.
  /// @param _configs The token configs to set.
  function addOrUpdateAcceptedToken(address[] calldata _tokens, HLPTokenConfig[] calldata _configs) external onlyOwner {
    if (_tokens.length != _configs.length) {
      revert IConfigStorage_BadLen();
    }

    uint256 _tokenLen = _tokens.length;
    for (uint256 _i; _i < _tokenLen; ) {
      bytes32 _assetId = tokenAssetIds[_tokens[_i]];

      uint256 _assetIdLen = hlpAssetIds.length;

      bool _isSetHLPAssetId = true;

      for (uint256 _j; _j < _assetIdLen; ) {
        if (hlpAssetIds[_j] == _assetId) {
          _isSetHLPAssetId = false;
        }
        unchecked {
          ++_j;
        }
      }

      // Adjust hlpTotalToken Weight
      if (liquidityConfig.hlpTotalTokenWeight == 0) {
        liquidityConfig.hlpTotalTokenWeight = _configs[_i].targetWeight;
      } else {
        liquidityConfig.hlpTotalTokenWeight =
          (liquidityConfig.hlpTotalTokenWeight - assetHlpTokenConfigs[_assetId].targetWeight) +
          _configs[_i].targetWeight;
      }

      if (liquidityConfig.hlpTotalTokenWeight > 1e18) {
        revert IConfigStorage_ExceedLimitSetting();
      }

      // put asset ID after add totalWeight
      if (_isSetHLPAssetId) {
        hlpAssetIds.push(_assetId);
      }

      assetHlpTokenConfigs[_assetId] = _configs[_i];
      emit LogAddOrUpdateHLPTokenConfigs(_tokens[_i], assetHlpTokenConfigs[_assetId], _configs[_i]);

      // Update totalWeight accordingly

      unchecked {
        ++_i;
      }
    }
  }

  function addAssetClassConfig(AssetClassConfig calldata _newConfig) external onlyOwner returns (uint256 _index) {
    uint256 _newAssetClassIndex = assetClassConfigs.length;
    assetClassConfigs.push(_newConfig);
    emit LogAddAssetClassConfig(_newAssetClassIndex, _newConfig);
    return _newAssetClassIndex;
  }

  function setAssetClassConfigByIndex(uint256 _index, AssetClassConfig calldata _newConfig) external onlyOwner {
    emit LogSetAssetClassConfigByIndex(_index, assetClassConfigs[_index], _newConfig);
    assetClassConfigs[_index] = _newConfig;
  }

  function addMarketConfig(MarketConfig calldata _newConfig) external onlyOwner returns (uint256 _index) {
    uint256 _newMarketIndex = marketConfigs.length;
    marketConfigs.push(_newConfig);
    emit LogAddMarketConfig(_newMarketIndex, _newConfig);
    return _newMarketIndex;
  }

  function delistMarket(uint256 _marketIndex) external onlyOwner {
    emit LogDelistMarket(_marketIndex);
    delete marketConfigs[_marketIndex].active;
  }

  /// @notice Remove underlying token.
  /// @param _token The token address to remove.
  function removeAcceptedToken(address _token) external onlyOwner {
    bytes32 _assetId = tokenAssetIds[_token];

    // Update totalTokenWeight
    liquidityConfig.hlpTotalTokenWeight -= assetHlpTokenConfigs[_assetId].targetWeight;

    // delete from hlpAssetIds
    uint256 _len = hlpAssetIds.length;
    for (uint256 _i = 0; _i < _len; ) {
      if (_assetId == hlpAssetIds[_i]) {
        delete hlpAssetIds[_i];
        break;
      }

      unchecked {
        ++_i;
      }
    }
    // Delete hlpTokenConfig
    delete assetHlpTokenConfigs[_assetId];

    emit LogRemoveUnderlying(_token);
  }

  function setTradeServiceHooks(address[] calldata _newHooks) external onlyOwner {
    tradeServiceHooks = _newHooks;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
