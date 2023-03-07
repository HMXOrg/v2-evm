// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest } from "./BaseIntTest.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetMarkets is BaseIntTest {
  // crypto
  bytes32 internal constant wethAssetId = "weth";
  bytes32 internal constant wbtcAssetId = "wbtc";
  bytes32 internal constant daiAssetId = "dai";
  bytes32 internal constant usdcAssetId = "usdc";
  bytes32 internal constant usdtAssetId = "usdt";
  bytes32 internal constant gmxAssetId = "gmx";

  // stock
  bytes32 internal constant appleAssetId = "apple";

  // forex
  bytes32 internal constant jpyAssetId = "jpy";

  // @todo - setting discuss
  constructor() {
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(wethAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(wbtcAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(daiAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(usdcAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(usdtAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(gmxAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(appleAssetId, 1, 100, 50);
    // IMF = 1%, Max leverage = 100, MMF = 0.5%
    _addMarketConfig(jpyAssetId, 1, 100, 50);
  }

  /// @notice to add market config with some default value
  /// @param _assetId Asset's ID
  /// @param _assetClass Crypto = 1, Stock = 2, Forex = 3
  /// @param _imf Initail Margin Fraction
  /// @param _mmf Maintenance Margin Fraction
  function _addMarketConfig(bytes32 _assetId, uint8 _assetClass, uint32 _imf, uint32 _mmf) private {
    // default market config
    // IConfigStorage.MarketConfig memory _newMarketConfig;
    // IConfigStorage.OpenInterest memory _newOpenInterestConfig;
    // IConfigStorage.FundingRate memory _newFundingRateConfig;
    // defaultOpenInterestConfig.longMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;
    // defaultOpenInterestConfig.shortMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;
    // defaultFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
    // defaultFundingRateConfig.maxFundingRateBPS = 4; // 0.04%
    // defaultMarketConfig.assetId = _assetId;
    // defaultMarketConfig.increasePositionFeeRateBPS = 50; // 0.5%
    // defaultMarketConfig.decreasePositionFeeRateBPS = 50; // 0.5%
    // defaultMarketConfig.initialMarginFractionBPS = _imf;
    // defaultMarketConfig.maintenanceMarginFractionBPS = _mmf;
    // defaultMarketConfig.maxProfitRateBPS = 90000; // 900%
    // defaultMarketConfig.minLeverageBPS = 11000; // 110%
    // defaultMarketConfig.assetClass = _assetClass;
    // defaultMarketConfig.allowIncreasePosition = true;
    // defaultMarketConfig.active = true;
    // defaultMarketConfig.openInterest = defaultOpenInterestConfig;
    // defaultMarketConfig.fundingRate = defaultFundingRateConfig;
    // configStorage.addMarketConfig(_newMarketConfig);
  }
}
