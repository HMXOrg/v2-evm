// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";
import { PythAdapter } from "@hmx/oracle/PythAdapter.sol";

contract SetOracle is ConfigJsonRepo {
  error BadArgs();

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

  struct AssetPythPriceData {
    bytes32 assetId;
    bytes32 priceId;
    int64 price;
    int64 exponent;
    bool inverse;
  }

  AssetPythPriceData[] assetPythPriceDatas;
  /// @notice will change when a function called "setPrices" is used or when an object is created through a function called "constructor"
  bytes[] initialPriceFeedDatas;

  IOracleMiddleware oracleMiddleWare;
  PythAdapter pythAdapter;
  IPyth pyth;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    oracleMiddleWare = IOracleMiddleware(getJsonAddress(".oracle.middleware"));
    pythAdapter = PythAdapter(getJsonAddress(".oracle.pythAdapter"));
    pyth = IPyth(getJsonAddress(".oracle.leanPyth"));

    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: wethAssetId, priceId: wethPriceId, price: 1500, exponent: -8, inverse: false })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: wbtcAssetId, priceId: wbtcPriceId, price: 20000, exponent: -8, inverse: false })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: daiAssetId, priceId: daiPriceId, price: 1, exponent: -8, inverse: false })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: usdcAssetId, priceId: usdcPriceId, price: 1, exponent: -8, inverse: false })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: usdtAssetId, priceId: usdtPriceId, price: 1, exponent: -8, inverse: false })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: appleAssetId, priceId: applePriceId, price: 152, exponent: -5, inverse: false })
    );
    // @todo - after integrate with inverse config then price should be change to USDJPY
    assetPythPriceDatas.push(
      AssetPythPriceData({ assetId: jpyAssetId, priceId: jpyPriceId, price: 0.0072 * 1e8, exponent: -8, inverse: true })
    );

    // Set MarketStatus
    uint8 _marketActiveStatus = uint8(2);
    oracleMiddleWare.setUpdater(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a, true);
    // crypto
    oracleMiddleWare.setMarketStatus(usdcAssetId, _marketActiveStatus); // active
    oracleMiddleWare.setMarketStatus(usdtAssetId, _marketActiveStatus); // active
    oracleMiddleWare.setMarketStatus(daiAssetId, _marketActiveStatus); // active
    oracleMiddleWare.setMarketStatus(wethAssetId, _marketActiveStatus); // active
    oracleMiddleWare.setMarketStatus(wbtcAssetId, _marketActiveStatus); // active
    // equity
    oracleMiddleWare.setMarketStatus(appleAssetId, _marketActiveStatus); // active
    // forex
    oracleMiddleWare.setMarketStatus(jpyAssetId, _marketActiveStatus); // active

    // Set AssetPriceConfig
    uint32 _confidenceThresholdE6 = 100000; // 2.5% for test only
    uint32 _trustPriceAge = 365 days; // set max for test only
    oracleMiddleWare.setAssetPriceConfig(wethAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(wbtcAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(daiAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(usdcAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(usdtAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(appleAssetId, _confidenceThresholdE6, _trustPriceAge);
    oracleMiddleWare.setAssetPriceConfig(jpyAssetId, _confidenceThresholdE6, _trustPriceAge);

    AssetPythPriceData memory _data;

    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      _data = assetPythPriceDatas[i];

      // set PythId
      pythAdapter.setConfig(_data.assetId, _data.priceId, _data.inverse);

      unchecked {
        ++i;
      }
    }
    vm.stopBroadcast();
  }
}
