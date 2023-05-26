// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConfigStorage {
  /**
   * Errors
   */
  error IConfigStorage_InvalidAddress();
  error IConfigStorage_NotWhiteListed();
  error IConfigStorage_ExceedLimitSetting();
  error IConfigStorage_BadLen();
  error IConfigStorage_BadArgs();
  error IConfigStorage_NotAcceptedCollateral();
  error IConfigStorage_NotAcceptedLiquidity();
  error IConfigStorage_MaxFeeBps();
  error IConfigStorage_InvalidAssetClass();

  /**
   * Structs
   */
  /// @notice Asset's config
  struct AssetConfig {
    address tokenAddress;
    bytes32 assetId;
    uint8 decimals;
    bool isStableCoin; // token is stablecoin
  }

  /// @notice perp liquidity provider token config
  struct PLPTokenConfig {
    uint256 targetWeight; // percentage of all accepted PLP tokens
    uint256 bufferLiquidity; // liquidity reserved for swapping, decimal is depends on token
    uint256 maxWeightDiff; // Maximum difference from the target weight in %
    bool accepted; // accepted to provide liquidity
  }

  /// @notice collateral token config
  struct CollateralTokenConfig {
    address settleStrategy; // determine token will be settled for NON PLP collateral, e.g. aUSDC redeemed as USDC
    uint32 collateralFactorBPS; // token reliability factor to calculate buying power, 1e4 = 100%
    bool accepted; // accepted to deposit as collateral
  }

  struct FundingRate {
    uint256 maxSkewScaleUSD; // maximum skew scale for using maxFundingRate
    uint256 maxFundingRate; // maximum funding rate
  }

  struct MarketConfig {
    bytes32 assetId; // pyth network asset id
    uint256 maxLongPositionSize; //
    uint256 maxShortPositionSize; //
    uint32 increasePositionFeeRateBPS; // fee rate to increase position
    uint32 decreasePositionFeeRateBPS; // fee rate to decrease position
    uint32 initialMarginFractionBPS; // IMF
    uint32 maintenanceMarginFractionBPS; // MMF
    uint32 maxProfitRateBPS; // maximum profit that trader could take per position
    uint32 minLeverageBPS; // OBSOLETED
    uint8 assetClass; // Crypto = 1, Forex = 2, Stock = 3
    bool allowIncreasePosition; // allow trader to increase position
    bool active; // if active = false, means this market is delisted
    FundingRate fundingRate;
  }

  struct AssetClassConfig {
    uint256 baseBorrowingRate;
  }

  struct LiquidityConfig {
    uint256 plpTotalTokenWeight; // % of token Weight (must be 1e18)
    uint32 plpSafetyBufferBPS; // for PLP deleverage
    uint32 taxFeeRateBPS; // PLP deposit, withdraw, settle collect when pool weight is imbalances
    uint32 flashLoanFeeRateBPS;
    uint32 maxPLPUtilizationBPS; //% of max utilization
    uint32 depositFeeRateBPS; // PLP deposit fee rate
    uint32 withdrawFeeRateBPS; // PLP withdraw fee rate
    bool dynamicFeeEnabled; // if disabled, swap, add or remove liquidity will exclude tax fee
    bool enabled; // Circuit breaker on Liquidity
  }

  struct SwapConfig {
    uint32 stablecoinSwapFeeRateBPS;
    uint32 swapFeeRateBPS;
  }

  struct TradingConfig {
    uint256 fundingInterval; // funding interval unit in seconds
    uint256 minProfitDuration;
    uint32 devFeeRateBPS;
    uint8 maxPosition;
  }

  struct LiquidationConfig {
    uint256 liquidationFeeUSDE30; // liquidation fee in USD
  }

  /**
   * States
   */

  function calculator() external view returns (address);

  function oracle() external view returns (address);

  function plp() external view returns (address);

  function treasury() external view returns (address);

  function pnlFactorBPS() external view returns (uint32);

  function weth() external view returns (address);

  function tokenAssetIds(address _token) external view returns (bytes32);

  /**
   * Functions
   */
  function validateServiceExecutor(address _contractAddress, address _executorAddress) external view;

  function validateAcceptedLiquidityToken(address _token) external view;

  function validateAcceptedCollateral(address _token) external view;

  function getTradingConfig() external view returns (TradingConfig memory);

  function getMarketConfigs() external view returns (MarketConfig[] memory);

  function getMarketConfigByIndex(uint256 _index) external view returns (MarketConfig memory _marketConfig);

  function getAssetClassConfigByIndex(uint256 _index) external view returns (AssetClassConfig memory _assetClassConfig);

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory _collateralTokenConfig);

  function getAssetTokenDecimal(address _token) external view returns (uint8);

  function getLiquidityConfig() external view returns (LiquidityConfig memory);

  function getLiquidationConfig() external view returns (LiquidationConfig memory);

  function getMarketConfigsLength() external view returns (uint256);

  function getPlpTokens() external view returns (address[] memory);

  function getAssetConfigByToken(address _token) external view returns (AssetConfig memory);

  function getCollateralTokens() external view returns (address[] memory);

  function getAssetConfig(bytes32 _assetId) external view returns (AssetConfig memory);

  function getAssetPlpTokenConfig(bytes32 _assetId) external view returns (PLPTokenConfig memory);

  function getAssetPlpTokenConfigByToken(address _token) external view returns (PLPTokenConfig memory);

  function getPlpAssetIds() external view returns (bytes32[] memory);

  function getTradeServiceHooks() external view returns (address[] memory);

  function setMinimumPositionSize(uint256 _minimumPositionSize) external;

  function setLiquidityEnabled(bool _enabled) external;

  function setDynamicEnabled(bool _enabled) external;

  function setCalculator(address _calculator) external;

  function setOracle(address _oracle) external;

  function setPLP(address _plp) external;

  function setLiquidityConfig(LiquidityConfig memory _liquidityConfig) external;

  function setServiceExecutor(address _contractAddress, address _executorAddress, bool _isServiceExecutor) external;

  function setServiceExecutors(
    address[] calldata _contractAddresses,
    address[] calldata _executorAddresses,
    bool[] calldata _isServiceExecutors
  ) external;

  function setPnlFactor(uint32 _pnlFactor) external;

  function setSwapConfig(SwapConfig memory _newConfig) external;

  function setTradingConfig(TradingConfig memory _newConfig) external;

  function setLiquidationConfig(LiquidationConfig memory _newConfig) external;

  function setMarketConfig(
    uint256 _marketIndex,
    MarketConfig memory _newConfig
  ) external returns (MarketConfig memory _marketConfig);

  function setPlpTokenConfig(
    address _token,
    PLPTokenConfig memory _newConfig
  ) external returns (PLPTokenConfig memory _plpTokenConfig);

  function setCollateralTokenConfig(
    bytes32 _assetId,
    CollateralTokenConfig memory _newConfig
  ) external returns (CollateralTokenConfig memory _collateralTokenConfig);

  function setAssetConfig(
    bytes32 assetId,
    AssetConfig memory _newConfig
  ) external returns (AssetConfig memory _assetConfig);

  function setConfigExecutor(address _executorAddress, bool _isServiceExecutor) external;

  function setWeth(address _weth) external;

  function setSGlp(address _sglp) external;

  function addOrUpdateAcceptedToken(address[] calldata _tokens, PLPTokenConfig[] calldata _configs) external;

  function addAssetClassConfig(AssetClassConfig calldata _newConfig) external returns (uint256 _index);

  function setAssetClassConfigByIndex(uint256 _index, AssetClassConfig calldata _newConfig) external;

  function setTradeServiceHooks(address[] calldata _newHooks) external;

  function addMarketConfig(MarketConfig calldata _newConfig) external returns (uint256 _index);

  function delistMarket(uint256 _marketIndex) external;

  function removeAcceptedToken(address _token) external;
}
