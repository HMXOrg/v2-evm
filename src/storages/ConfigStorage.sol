// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { IConfigStorage } from "./interfaces/IConfigStorage.sol";

/// @title ConfigStorage
/// @notice storage contract to keep configs
contract ConfigStorage is IConfigStorage {
  /// @notice asset class
  enum AssetClass {
    Crypto
  }

  /// @notice perp liquidity provider token config
  struct PLPTokenConfig {
    uint8 decimals;
    uint256 targetWeight;
    uint256 bufferLiquidity; // liquidity reserved for swapping, decimal is depends on token
    uint256 maxWeightDiff;
    bool isStableCoin; // token is stablecoin
    bool accepted; // accepted to provide liquidity
  }

  /// @notice collateral token config
  struct CollateralTokenConfig {
    uint8 decimals;
    uint256 collateralFactor; // token reliability factor to calculate buying power, 1e18 = 100%
    bool isStableCoin; // token is stablecoin
    bool accepted; // accepted to deposit as collateral
    address settleStrategy; // determine token will be settled for NON PLP collateral, e.g. aUSDC redeemed as USDC
  }

  struct MarketConfig {
    bytes32 assetId; // pyth network asset id
    uint256 maxProfitRate; // maximum profit that trader could take per position
    uint256 longMaxOpenInterestUSDE30; // maximum to open long position
    uint256 shortMaxOpenInterestUSDE30; // maximum to open short position
    uint256 maxLeverage; // maximum leverage that trader could open position
    uint256 minLeverage; // minimum leverage that trader could open position
    uint256 initialMarginFraction; // IMF
    uint256 maintenanceMarginFraction; // MMF
    uint256 increasePositionFeeRate; // fee rate to increase position
    uint256 decreasePositionFeeRate; // fee rate to decrease position
    uint256 maxFundingRate; // maximum funding rate
    uint256 priceConfidentThreshold; // pyth price confidential treshold
    AssetClass assetClass;
    bool allowIncreasePosition; // allow trader to increase position
    bool active; // if active = false, means this market is delisted
  }

  struct AssetClassConfig {
    uint256 baseBorrowingRate;
  }

  // GLOBAL Parameter Configs
  // Liquidity
  uint256 depositFeeRate; // PLP deposit fee rate
  uint256 withdrawFeeRate; // PLP withdraw fee rate
  uint256 maxPLPUtilization;
  uint256 plpSafetyBufferThreshold;
  uint256 taxFee; // PLP deposit, withdraw, settle collect when pool weight is imbalances
  uint256 dynamicFeeEnabled; // if disabled, swap, add or remove liquidity will exclude tax fee ??
  uint256 flashLoanFeeRate;

  // Swap
  uint256 stablecoinSwapFee;
  uint256 swapFee;

  // Trading
  uint256 fundingInterval; // funding interval unit in seconds
  uint256 borrowingDevFeeRate;

  // Liquidation
  uint256 liquidationFee;

  MarketConfig[] marketConfigs;

  mapping(address => PLPTokenConfig) plpTokenConfigs; // token => config
  mapping(address => CollateralTokenConfig) colalteralTokenConfigs; // token => config

  mapping(address => bool) allowedLiquidators; // allowed contract to execute liquidation service
  mapping(address => mapping(address => bool)) serviceExecutors; // to allowed executor for service layer

  
}
