// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

// for local only
contract SetMarkets is ConfigJsonRepo {
  uint256 internal constant DOLLAR = 1e30;

  // Arbitrum Goerli Price Feed IDs (https://pyth.network/developers/price-feed-ids#pyth-evm-testnet)
  bytes32 internal constant wethPriceId = 0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6;
  bytes32 internal constant wbtcPriceId = 0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b;
  bytes32 internal constant usdcPriceId = 0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722;
  bytes32 internal constant usdtPriceId = 0x1fc18861232290221461220bd4e2acd1dcdfbc89c84092c93c18bdc7756c1588;
  bytes32 internal constant daiPriceId = 0x87a67534df591d2dd5ec577ab3c75668a8e3d35e92e27bf29d9e2e52df8de412;
  bytes32 internal constant applePriceId = 0xafcc9a5bb5eefd55e12b6f0b4c8e6bccf72b785134ee232a5d175afd082e8832;
  bytes32 internal constant jpyPriceId = 0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776;

  bytes32 constant wethAssetId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 constant wbtcAssetId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 constant usdcAssetId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 constant usdtAssetId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 constant daiAssetId = 0x0000000000000000000000000000000000000000000000000000000000000005;
  bytes32 constant appleAssetId = 0x0000000000000000000000000000000000000000000000000000000000000006;
  bytes32 constant jpyAssetId = 0x0000000000000000000000000000000000000000000000000000000000000007;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    _addMarketConfig(wethAssetId, 1, 100, 50, 10);
    // IMF = 1%, Max leverage = 100
    // MMF = 0.5%
    // Increase / Decrease position fee = 0.1%
    _addMarketConfig(wbtcAssetId, 1, 100, 50, 10);
    // IMF = 5%, Max leverage = 20
    // MMF = 2.5%
    // Increase / Decrease position fee = 0.05%
    _addMarketConfig(appleAssetId, 1, 500, 250, 5);
    // IMF = 0.1%, Max leverage = 1000
    // MMF = 0.05%
    // Increase / Decrease position fee = 0.03%
    _addMarketConfig(jpyAssetId, 1, 10, 5, 3);

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
    IConfigStorage.OpenInterest memory _newOpenInterestConfig;
    IConfigStorage.FundingRate memory _newFundingRateConfig;

    _newOpenInterestConfig.longMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;
    _newOpenInterestConfig.shortMaxOpenInterestUSDE30 = 10_000_000 * DOLLAR;

    _newFundingRateConfig.maxSkewScaleUSD = 3_000_000 * DOLLAR;
    _newFundingRateConfig.maxFundingRateBPS = 4; // 0.04%

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
