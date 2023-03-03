// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConfigStorage {
  /**
   * Errors
   */
  error IConfigStorage_NotWhiteListed();
  error IConfigStorage_ExceedLimitSetting();
  error IConfigStorage_BadLen();
  error IConfigStorage_BadArgs();
  error IConfigStorage_NotAcceptedCollateral();
  error IConfigStorage_NotAcceptedLiquidity();

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

  struct OpenInterest {
    uint256 longMaxOpenInterestUSDE30; // maximum to open long position
    uint256 shortMaxOpenInterestUSDE30; // maximum to open short position
  }

  struct FundingRate {
    uint256 maxSkewScaleUSD; // maximum skew scale for using maxFundingRateBPS
    uint32 maxFundingRateBPS; // maximum funding rate
  }

  struct MarketConfig {
    bytes32 assetId; // pyth network asset id
    uint32 increasePositionFeeRateBPS; // fee rate to increase position
    uint32 decreasePositionFeeRateBPS; // fee rate to decrease position
    uint32 initialMarginFractionBPS; // IMF
    uint32 maintenanceMarginFractionBPS; // MMF
    uint32 maxProfitRateBPS; // maximum profit that trader could take per position
    uint32 minLeverageBPS; // minimum leverage that trader could open position
    uint8 assetClass; // Crypto = 1, Forex = 2, Stock = 3
    bool allowIncreasePosition; // allow trader to increase position
    bool active; // if active = false, means this market is delisted
    OpenInterest openInterest;
    FundingRate fundingRate;
  }

  struct AssetClassConfig {
    uint32 baseBorrowingRateBPS;
  }

  struct LiquidityConfig {
    uint256 plpTotalTokenWeight; // % of token Weight (must be 1e18)
    uint256 plpSafetyBufferThreshold;
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
   * State Getter
   */

  function calculator() external view returns (address);

  function feeCalculator() external view returns (address);

  function oracle() external view returns (address);

  function plp() external view returns (address);

  function treasury() external view returns (address);

  function pnlFactorBPS() external view returns (uint32);

  function weth() external view returns (address);

  /**
   * Validation
   */
  function validateServiceExecutor(address _contractAddress, address _executorAddress) external view;

  function validateAcceptedCollateral(address _token) external view;

  function validateAcceptedLiquidityToken(address _token) external view;

  /**
   * Getter
   */
  function ITERABLE_ADDRESS_LIST_START() external view returns (address);

  function ITERABLE_ADDRESS_LIST_END() external view returns (address);

  function getMarketConfigByIndex(uint256 _index) external view returns (MarketConfig memory _marketConfig);

  function getAssetClassConfigByIndex(uint256 _index) external view returns (AssetClassConfig memory _assetClassConfig);

  function getTradingConfig() external view returns (TradingConfig memory);

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory _collateralTokenConfig);

  function getLiquidityConfig() external view returns (LiquidityConfig memory);

  function getLiquidationConfig() external view returns (LiquidationConfig memory);

  function getMarketConfigByToken(address _token) external view returns (MarketConfig memory);

  function getMarketConfigsLength() external view returns (uint256);

  function getPlpTokens() external view returns (address[] memory);

  function getCollateralTokens() external view returns (address[] memory);

  function getAssetConfigByToken(address _token) external view returns (AssetConfig memory);

  function getPlpAssetIds() external view returns (bytes32[] memory);

  function getAssetConfig(bytes32 _assetId) external view returns (AssetConfig memory);

  function getAssetPlpTokenConfig(bytes32 _assetId) external view returns (PLPTokenConfig memory);

  function getAssetPlpTokenConfigByToken(address _token) external view returns (PLPTokenConfig memory);

  function tokenAssetIds(address _token) external view returns (bytes32);

  function getAssetTokenDecimal(address _token) external view returns (uint8);

  /**
   * Setter
   */

  function setCalculator(address _calculator) external;

  function setOracle(address _oracle) external;

  function setPLP(address _plp) external;

  function setPLPTotalTokenWeight(uint256 _totalTokenWeight) external;

  function setServiceExecutor(address _contractAddress, address _executorAddress, bool _isServiceExecutor) external;

  function addAssetClassConfig(AssetClassConfig calldata _newConfig) external returns (uint256 _index);

  function addMarketConfig(MarketConfig calldata _newConfig) external returns (uint256 _index);

  function setLiquidityConfig(LiquidityConfig memory _newConfig) external;

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
    bytes32 collateralAssetId,
    CollateralTokenConfig memory _newConfig
  ) external returns (CollateralTokenConfig memory _collateralTokenConfig);

  function setWeth(address _weth) external;

  function setAssetClassConfigByIndex(uint256 _index, AssetClassConfig calldata _newConfig) external;
}
