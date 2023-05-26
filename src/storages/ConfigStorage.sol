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
  event LogSetPLP(address indexed oldPlp, address newPlp);
  event LogSetLiquidityConfig(LiquidityConfig indexed oldLiquidityConfig, LiquidityConfig newLiquidityConfig);
  event LogSetDynamicEnabled(bool enabled);
  event LogSetPnlFactor(uint32 oldPnlFactorBPS, uint32 newPnlFactorBPS);
  event LogSetSwapConfig(SwapConfig indexed oldConfig, SwapConfig newConfig);
  event LogSetTradingConfig(TradingConfig indexed oldConfig, TradingConfig newConfig);
  event LogSetLiquidationConfig(LiquidationConfig indexed oldConfig, LiquidationConfig newConfig);
  event LogSetMarketConfig(uint256 marketIndex, MarketConfig oldConfig, MarketConfig newConfig);
  event LogSetPlpTokenConfig(address token, PLPTokenConfig oldConfig, PLPTokenConfig newConfig);
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
  event LogAddOrUpdatePLPTokenConfigs(address _token, PLPTokenConfig _config, PLPTokenConfig _newConfig);
  event LogSetTradeServiceHooks(address[] oldHooks, address[] newHooks);

  /**
   * Constants
   */
  address public constant ITERABLE_ADDRESS_LIST_START = address(1);
  address public constant ITERABLE_ADDRESS_LIST_END = address(1);
  uint256 public constant BPS = 1e4;
  uint256 public constant MAX_FEE_BPS = 0.3 * 1e4; // 30%

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
  address public plp;
  address public treasury;
  uint32 public pnlFactorBPS; // factor that calculate unrealized PnL after collateral factor
  uint256 public minimumPositionSize;
  address public weth;
  address public sglp;

  // Token's address => Asset ID
  mapping(address => bytes32) public tokenAssetIds;
  // Asset ID => Configs
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
    if (!assetPlpTokenConfigs[tokenAssetIds[_token]].accepted) revert IConfigStorage_NotAcceptedLiquidity();
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

  function setConfigExecutor(address _executorAddress, bool _isServiceExecutor) external onlyOwner {
    configExecutors[_executorAddress] = _isServiceExecutor;
    emit LogSetConfigExecutor(_executorAddress, _isServiceExecutor);
  }

  function setMinimumPositionSize(uint256 _minimumPositionSize) external onlyOwner {
    emit LogSetMinimumPositionSize(minimumPositionSize, _minimumPositionSize);
    minimumPositionSize = _minimumPositionSize;
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

  function setPLP(address _plp) external onlyOwner {
    if (_plp == address(0)) revert IConfigStorage_InvalidAddress();
    emit LogSetPLP(plp, _plp);

    plp = _plp;
  }

  function setLiquidityConfig(LiquidityConfig memory _liquidityConfig) external onlyOwner {
    if (
      _liquidityConfig.taxFeeRateBPS > MAX_FEE_BPS ||
      _liquidityConfig.flashLoanFeeRateBPS > MAX_FEE_BPS ||
      _liquidityConfig.depositFeeRateBPS > MAX_FEE_BPS ||
      _liquidityConfig.withdrawFeeRateBPS > MAX_FEE_BPS
    ) revert IConfigStorage_MaxFeeBps();
    if (_liquidityConfig.maxPLPUtilizationBPS > BPS) revert IConfigStorage_ExceedLimitSetting();
    emit LogSetLiquidityConfig(liquidityConfig, _liquidityConfig);
    liquidityConfig = _liquidityConfig;

    uint256 plpTotalTokenWeight = 0;
    for (uint256 i = 0; i < plpAssetIds.length; ) {
      plpTotalTokenWeight += assetPlpTokenConfigs[plpAssetIds[i]].targetWeight;

      unchecked {
        ++i;
      }
    }

    liquidityConfig.plpTotalTokenWeight = plpTotalTokenWeight;
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
    _setServiceExecutor(_contractAddress, _executorAddress, _isServiceExecutor);
  }

  function _setServiceExecutor(address _contractAddress, address _executorAddress, bool _isServiceExecutor) internal {
    if (
      _contractAddress == address(0) ||
      _executorAddress == address(0) ||
      !isContract(_contractAddress) ||
      !isContract(_executorAddress)
    ) revert IConfigStorage_InvalidAddress();
    serviceExecutors[_contractAddress][_executorAddress] = _isServiceExecutor;
    emit LogSetServiceExecutor(_contractAddress, _executorAddress, _isServiceExecutor);
  }

  function setServiceExecutors(
    address[] calldata _contractAddresses,
    address[] calldata _executorAddresses,
    bool[] calldata _isServiceExecutors
  ) external onlyOwner {
    if (
      _contractAddresses.length != _executorAddresses.length && _executorAddresses.length != _isServiceExecutors.length
    ) revert IConfigStorage_BadArgs();

    for (uint256 i = 0; i < _contractAddresses.length; ) {
      _setServiceExecutor(_contractAddresses[i], _executorAddresses[i], _isServiceExecutors[i]);
      unchecked {
        ++i;
      }
    }
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
    if (_newConfig.fundingInterval == 0 || _newConfig.devFeeRateBPS > MAX_FEE_BPS)
      revert IConfigStorage_ExceedLimitSetting();
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
    if (_newConfig.increasePositionFeeRateBPS > MAX_FEE_BPS || _newConfig.decreasePositionFeeRateBPS > MAX_FEE_BPS)
      revert IConfigStorage_MaxFeeBps();
    if (_newConfig.assetClass > assetClassConfigs.length - 1) revert IConfigStorage_InvalidAssetClass();

    emit LogSetMarketConfig(_marketIndex, marketConfigs[_marketIndex], _newConfig);
    marketConfigs[_marketIndex] = _newConfig;
    return marketConfigs[_marketIndex];
  }

  function setPlpTokenConfig(
    address _token,
    PLPTokenConfig memory _newConfig
  ) external onlyOwner returns (PLPTokenConfig memory _plpTokenConfig) {
    emit LogSetPlpTokenConfig(_token, assetPlpTokenConfigs[tokenAssetIds[_token]], _newConfig);
    assetPlpTokenConfigs[tokenAssetIds[_token]] = _newConfig;

    uint256 plpTotalTokenWeight = 0;
    for (uint256 i = 0; i < plpAssetIds.length; ) {
      plpTotalTokenWeight += assetPlpTokenConfigs[plpAssetIds[i]].targetWeight;

      unchecked {
        ++i;
      }
    }

    liquidityConfig.plpTotalTokenWeight = plpTotalTokenWeight;

    return _newConfig;
  }

  function setCollateralTokenConfig(
    bytes32 _assetId,
    CollateralTokenConfig memory _newConfig
  ) external onlyOwner returns (CollateralTokenConfig memory _collateralTokenConfig) {
    if (_newConfig.collateralFactorBPS == 0) revert IConfigStorage_ExceedLimitSetting();

    emit LogSetCollateralTokenConfig(_assetId, assetCollateralTokenConfigs[_assetId], _newConfig);
    // get current config, if new collateral's assetId then push to array
    CollateralTokenConfig memory _curCollateralTokenConfig = assetCollateralTokenConfigs[_assetId];
    if (
      _curCollateralTokenConfig.settleStrategy == address(0) &&
      _curCollateralTokenConfig.collateralFactorBPS == 0 &&
      _curCollateralTokenConfig.accepted == false
    ) {
      collateralAssetIds.push(_assetId);
    }
    assetCollateralTokenConfigs[_assetId] = _newConfig;
    return assetCollateralTokenConfigs[_assetId];
  }

  function setAssetConfig(
    bytes32 _assetId,
    AssetConfig memory _newConfig
  ) external onlyOwner returns (AssetConfig memory _assetConfig) {
    if (!isContract(_newConfig.tokenAddress)) revert IConfigStorage_BadArgs();

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
    if (!isContract(_weth)) revert IConfigStorage_BadArgs();

    emit LogSetToken(weth, _weth);
    weth = _weth;
  }

  function setSGlp(address _sglp) external onlyOwner {
    if (!isContract(_sglp)) revert IConfigStorage_BadArgs();

    emit LogSetToken(sglp, _sglp);
    sglp = _sglp;
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

    uint256 _tokenLen = _tokens.length;
    for (uint256 _i; _i < _tokenLen; ) {
      bytes32 _assetId = tokenAssetIds[_tokens[_i]];

      uint256 _assetIdLen = plpAssetIds.length;

      bool _isSetPLPAssetId = true;

      for (uint256 _j; _j < _assetIdLen; ) {
        if (plpAssetIds[_j] == _assetId) {
          _isSetPLPAssetId = false;
        }
        unchecked {
          ++_j;
        }
      }

      // Adjust plpTotalToken Weight
      if (liquidityConfig.plpTotalTokenWeight == 0) {
        liquidityConfig.plpTotalTokenWeight = _configs[_i].targetWeight;
      } else {
        liquidityConfig.plpTotalTokenWeight =
          (liquidityConfig.plpTotalTokenWeight - assetPlpTokenConfigs[_assetId].targetWeight) +
          _configs[_i].targetWeight;
      }

      // put asset ID after add totalWeight
      if (_isSetPLPAssetId) {
        plpAssetIds.push(_assetId);
      }

      emit LogAddOrUpdatePLPTokenConfigs(_tokens[_i], assetPlpTokenConfigs[_assetId], _configs[_i]);
      assetPlpTokenConfigs[_assetId] = _configs[_i];

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

  function addMarketConfig(MarketConfig calldata _newConfig) external onlyOwner returns (uint256 _newMarketIndex) {
    if (_newConfig.increasePositionFeeRateBPS > MAX_FEE_BPS || _newConfig.decreasePositionFeeRateBPS > MAX_FEE_BPS)
      revert IConfigStorage_MaxFeeBps();
    if (_newConfig.assetClass > assetClassConfigs.length - 1) revert IConfigStorage_InvalidAssetClass();

    _newMarketIndex = marketConfigs.length;
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
    liquidityConfig.plpTotalTokenWeight -= assetPlpTokenConfigs[_assetId].targetWeight;

    // delete from plpAssetIds
    uint256 _len = plpAssetIds.length;
    for (uint256 _i = 0; _i < _len; ) {
      if (_assetId == plpAssetIds[_i]) {
        plpAssetIds[_i] = plpAssetIds[_len - 1];
        plpAssetIds.pop();
        break;
      }

      unchecked {
        ++_i;
      }
    }
    // Delete plpTokenConfig
    delete assetPlpTokenConfigs[_assetId];

    emit LogRemoveUnderlying(_token);
  }

  function setTradeServiceHooks(address[] calldata _newHooks) external onlyOwner {
    for (uint256 i = 0; i < _newHooks.length; ) {
      if (_newHooks[i] == address(0)) revert IConfigStorage_InvalidAddress();

      unchecked {
        ++i;
      }
    }
    emit LogSetTradeServiceHooks(tradeServiceHooks, _newHooks);

    tradeServiceHooks = _newHooks;
  }

  function isContract(address _addr) internal returns (bool isContract) {
    uint32 size;
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
