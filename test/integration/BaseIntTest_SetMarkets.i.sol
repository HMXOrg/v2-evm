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
  /// @param _imf Initial Margin Fraction
  /// @param _mmf Maintenance Margin Fraction
  function _addMarketConfig(bytes32 _assetId, uint8 _assetClass, uint32 _imf, uint32 _mmf) private {
    // default market config
    IConfigStorage.MarketConfig memory _newMarketConfig;
    IConfigStorage.OpenInterest memory _newOpenInterestConfig;
    IConfigStorage.FundingRate memory _newFundingRateConfig;

    _newOpenInterestConfig.longMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;
    _newOpenInterestConfig.shortMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;

    _newFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
    _newFundingRateConfig.maxFundingRateBPS = 4; // 0.04%

    _newMarketConfig.assetId = _assetId;
    _newMarketConfig.increasePositionFeeRateBPS = 50; // 0.5%
    _newMarketConfig.decreasePositionFeeRateBPS = 50; // 0.5%
    _newMarketConfig.initialMarginFractionBPS = _imf;
    _newMarketConfig.maintenanceMarginFractionBPS = _mmf;
    _newMarketConfig.maxProfitRateBPS = 90000; // 900%
    _newMarketConfig.minLeverageBPS = 11000; // 110%
    _newMarketConfig.assetClass = _assetClass;
    _newMarketConfig.allowIncreasePosition = true;
    _newMarketConfig.active = true;
    _newMarketConfig.openInterest = _newOpenInterestConfig;
    _newMarketConfig.fundingRate = _newFundingRateConfig;

    configStorage.addMarketConfig(_newMarketConfig);
  }
}
