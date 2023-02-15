// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IConfigStorage {
  // ERRORs
  error NotAcceptedCollateral();
  error NotWhiteListed();

  /// @notice perp liquidity provider token config
  struct PLPTokenConfig {
    uint256 decimals;
    uint256 targetWeight; // pecentage of all accepted PLP tokens
    uint256 bufferLiquidity; // liquidity reserved for swapping, decimal is depends on token
    uint256 maxWeightDiff; // Maximum difference from the target weight in %
    bool isStableCoin; // token is stablecoin
    bool accepted; // accepted to provide liquidity
  }

  /// @notice collateral token config
  struct CollateralTokenConfig {
    uint256 decimals;
    uint256 collateralFactor; // token reliability factor to calculate buying power, 1e18 = 100%
    bool isStableCoin; // token is stablecoin
    bool accepted; // accepted to deposit as collateral
    address settleStrategy; // determine token will be settled for NON PLP collateral, e.g. aUSDC redeemed as USDC
  }

  struct MarketConfig {
    bytes32 assetId; // pyth network asset id
    uint256 assetClass; // Crypto = 1, Forex = 2, Stock = 3
    uint256 maxProfitRate; // maximum profit that trader could take per position
    uint256 longMaxOpenInterestUSDE30; // maximum to open long position
    uint256 shortMaxOpenInterestUSDE30; // maximum to open short position
    uint256 minLeverage; // minimum leverage that trader could open position
    uint256 initialMarginFraction; // IMF
    uint256 maintenanceMarginFraction; // MMF
    uint256 increasePositionFeeRate; // fee rate to increase position
    uint256 decreasePositionFeeRate; // fee rate to decrease position
    uint256 maxFundingRate; // maximum funding rate
    uint256 priceConfidentThreshold; // pyth price confidential treshold
    bool allowIncreasePosition; // allow trader to increase position
    bool active; // if active = false, means this market is delisted
  }

  struct AssetClassConfig {
    uint256 baseBorrowingRate;
  }

  // Liquidity
  struct LiquidityConfig {
    uint256 depositFeeRate; // PLP deposit fee rate
    uint256 withdrawFeeRate; // PLP withdraw fee rate
    uint256 maxPLPUtilization;
    uint256 plpSafetyBufferThreshold;
    uint256 taxFeeRate; // PLP deposit, withdraw, settle collect when pool weight is imbalances
    uint256 dynamicFeeEnabled; // if disabled, swap, add or remove liquidity will exclude tax fee
    uint256 flashLoanFeeRate;
  }

  // Swap
  struct SwapConfig {
    uint256 stablecoinSwapFeeRate;
    uint256 swapFeeRate;
  }

  // Trading
  struct TrandingConfig {
    uint256 fundingInterval; // funding interval unit in seconds
    uint256 borrowingDevFeeRate;
  }

  // Liquidation
  struct LiquidationConfig {
    uint256 liquidationFeeUSDE30; // liquidation fee in USD
  }

  function pnlFactor() external view returns (uint256);

  function validateServiceExecutor(
    address _contractAddress,
    address _executorAddress
  ) external view;

  function validateAcceptedCollateral(address _token) external view;

  function getCollateralTokenConfigs(
    address _token
  ) external view returns (CollateralTokenConfig memory collateralTokenConfig);

  function getMarketConfigByIndex(
    uint256 _index
  ) external view returns (MarketConfig memory marketConfig);

  function getMarketConfigByAssetId(
    bytes32 _assetId
  ) external view returns (MarketConfig memory marketConfig);
}
