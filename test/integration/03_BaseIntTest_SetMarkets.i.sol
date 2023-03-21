// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetConfig } from "./02_BaseIntTest_SetConfig.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetMarkets is BaseIntTest_SetConfig {
  // crypto
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

  // @todo - setting discuss
  constructor() {
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    wethMarketIndex = _addMarketConfig(wethAssetId, 1, 100, 50, 10);
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    wbtcMarketIndex = _addMarketConfig(wbtcAssetId, 1, 100, 50, 10);
    // IMF = 5%, Max leverage = 20
    // MMF = 2.5%
    // Increase / Decrease position fee = 0.05%
    appleMarketIndex = _addMarketConfig(appleAssetId, 1, 500, 250, 5);
    // IMF = 0.1%, Max leverage = 1000
    // MMF = 0.05%
    // Increase / Decrease position fee = 0.03%
    jpyMarketIndex = _addMarketConfig(jpyAssetId, 1, 10, 5, 3);
  }

  /// @notice to add market config with some default value
  /// @param _assetId Asset's ID
  /// @param _assetClass Crypto = 1, Stock = 2, Forex = 3
  /// @param _imf Initial Margin Fraction
  /// @param _mmf Maintenance Margin Fraction
  function _addMarketConfig(
    bytes32 _assetId,
    uint8 _assetClass,
    uint32 _imf,
    uint32 _mmf,
    uint32 _managePositionFee
  ) private returns (uint256 _index) {
    // default market config
    IConfigStorage.MarketConfig memory _newMarketConfig;
    IConfigStorage.OpenInterest memory _newOpenInterestConfig;
    IConfigStorage.FundingRate memory _newFundingRateConfig;

    _newOpenInterestConfig.longMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;
    _newOpenInterestConfig.shortMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;

    _newFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
    _newFundingRateConfig.maxFundingRate = 0.0004 * 1e18; // 0.04%

    _newMarketConfig.assetId = _assetId;
    _newMarketConfig.increasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.decreasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.initialMarginFractionBPS = _imf;
    _newMarketConfig.maintenanceMarginFractionBPS = _mmf;
    _newMarketConfig.maxProfitRateBPS = 90000; // 900%
    _newMarketConfig.minLeverageBPS = 11000; // 110%
    _newMarketConfig.assetClass = _assetClass;
    _newMarketConfig.allowIncreasePosition = true;
    _newMarketConfig.active = true;
    _newMarketConfig.openInterest = _newOpenInterestConfig;
    _newMarketConfig.fundingRate = _newFundingRateConfig;

    return configStorage.addMarketConfig(_newMarketConfig);
  }
}
