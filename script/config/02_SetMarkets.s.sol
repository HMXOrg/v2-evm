// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { HLP } from "@hmx/contracts/HLP.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract SetMarkets is ConfigJsonRepo {
  uint256 internal constant DOLLAR = 1e30;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    _addMarketConfig(wethAssetId, 0, 100, 50, 10);
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    _addMarketConfig(wbtcAssetId, 0, 100, 50, 10);
    // IMF = 5%, Max leverage = 20
    // MMF = 2.5%
    // Increase / Decrease position fee = 0.05%
    _addMarketConfig(appleAssetId, 1, 500, 250, 5);
    // IMF = 0.1%, Max leverage = 1000
    // MMF = 0.05%
    // Increase / Decrease position fee = 0.03%
    _addMarketConfig(jpyAssetId, 2, 10, 5, 3);

    vm.stopBroadcast();
  }

  function _addMarketConfig(
    bytes32 _assetId,
    uint8 _assetClass,
    uint32 _imf,
    uint32 _mmf,
    uint32 _managePositionFee
  ) private returns (uint256 _index) {
    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));

    // default market config
    IConfigStorage.MarketConfig memory _newMarketConfig;
    IConfigStorage.FundingRate memory _newFundingRateConfig;

    _newFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
    _newFundingRateConfig.maxFundingRate = 0.00000116 * 1e18; // 10% per day

    _newMarketConfig.assetId = _assetId;
    _newMarketConfig.increasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.decreasePositionFeeRateBPS = _managePositionFee;
    _newMarketConfig.initialMarginFractionBPS = _imf;
    _newMarketConfig.maintenanceMarginFractionBPS = _mmf;
    _newMarketConfig.maxProfitRateBPS = 90000; // 900%
    _newMarketConfig.assetClass = _assetClass;
    _newMarketConfig.allowIncreasePosition = true;
    _newMarketConfig.active = true;
    _newMarketConfig.fundingRate = _newFundingRateConfig;
    _newMarketConfig.maxLongPositionSize = 10_000_000 * 1e30;
    _newMarketConfig.maxShortPositionSize = 10_000_000 * 1e30;

    return configStorage.addMarketConfig(_newMarketConfig);
  }
}
