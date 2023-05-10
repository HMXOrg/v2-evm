// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetConfig } from "./02_BaseIntTest_SetConfig.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetMarkets is BaseIntTest_SetConfig {
  // crypto
  bytes32 internal constant sglpAssetId = "SGLPUSD";
  bytes32 internal constant wethAssetId = "WETHUSD";
  bytes32 internal constant wbtcAssetId = "WBTCUSD";
  bytes32 internal constant usdcAssetId = "USDCUSD";
  bytes32 internal constant usdtAssetId = "USDTUSD";
  bytes32 internal constant daiAssetId = "DAIUSD";

  // stock
  bytes32 internal constant appleAssetId = "AAPLUSD";

  // forex
  bytes32 internal constant jpyAssetId = "JPYUSD";

  uint256 wethMarketIndex;
  uint256 wbtcMarketIndex;
  uint256 appleMarketIndex;
  uint256 jpyMarketIndex;

  constructor() {
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    wethMarketIndex = addMarketConfig(wethAssetId, 0, 100, 50, 10);
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    wbtcMarketIndex = addMarketConfig(wbtcAssetId, 0, 100, 50, 10);
    // IMF = 5%, Max leverage = 20
    // MMF = 2.5%
    // Increase / Decrease position fee = 0.05%
    appleMarketIndex = addMarketConfig(appleAssetId, 1, 500, 250, 5);
    // IMF = 0.1%, Max leverage = 1000
    // MMF = 0.05%
    // Increase / Decrease position fee = 0.03%
    jpyMarketIndex = addMarketConfig(jpyAssetId, 2, 10, 5, 3);
  }

  /// @notice to add market config with some default value
  /// @param _assetId Asset's ID
  /// @param _assetClass Crypto = 1, Stock = 2, Forex = 3
  /// @param _imf Initial Margin Fraction
  /// @param _mmf Maintenance Margin Fraction
  function addMarketConfig(
    bytes32 _assetId,
    uint8 _assetClass,
    uint32 _imf,
    uint32 _mmf,
    uint32 _managePositionFee
  ) public returns (uint256 _index) {
    // default market config
    IConfigStorage.MarketConfig memory _newMarketConfig;
    IConfigStorage.FundingRate memory _newFundingRateConfig;

    _newFundingRateConfig.maxSkewScaleUSD = 300_000_000 * 1e30;
    _newFundingRateConfig.maxFundingRate = 0.0004 * 1e18; // 0.04%

    _newMarketConfig.assetId = _assetId;
    _newMarketConfig.maxLongPositionSize = 10_000_000 * 1e30;
    _newMarketConfig.maxShortPositionSize = 10_000_000 * 1e30;
    _newMarketConfig.increasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.decreasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.initialMarginFractionBPS = _imf;
    _newMarketConfig.maintenanceMarginFractionBPS = _mmf;
    _newMarketConfig.maxProfitRateBPS = 90000; // 900%
    _newMarketConfig.minLeverageBPS = 11000; // 110%
    _newMarketConfig.assetClass = _assetClass;
    _newMarketConfig.allowIncreasePosition = true;
    _newMarketConfig.active = true;
    _newMarketConfig.fundingRate = _newFundingRateConfig;

    return configStorage.addMarketConfig(_newMarketConfig);
  }
}
