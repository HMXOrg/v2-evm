// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";

contract SetOracle is ConfigJsonRepo {
  error BadArgs();

  uint256 internal constant DOLLAR = 1e30;

  struct AssetPythPriceData {
    bytes32 assetId;
    bool inverse;
  }

  AssetPythPriceData[] assetPythPriceDatas;
  /// @notice will change when a function called "setPrices" is used or when an object is created through a function called "constructor"
  bytes[] initialPriceFeedDatas;

  IOracleMiddleware oracleMiddleWare;
  PythAdapter pythAdapter;
  StakedGlpOracleAdapter stakedGlpOracleAdapter;
  EcoPyth ecoPyth;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    oracleMiddleWare = IOracleMiddleware(getJsonAddress(".oracles.middleware"));
    pythAdapter = PythAdapter(getJsonAddress(".oracles.pythAdapter"));
    ecoPyth = EcoPyth(getJsonAddress(".oracles.ecoPyth"));
    stakedGlpOracleAdapter = StakedGlpOracleAdapter(getJsonAddress(".oracles.sglpStakedAdapter"));

    assetPythPriceDatas.push(AssetPythPriceData({ assetId: wethAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: wbtcAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: daiAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: usdcAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: usdtAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: appleAssetId, inverse: false }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: jpyAssetId, inverse: true }));
    assetPythPriceDatas.push(AssetPythPriceData({ assetId: xauAssetId, inverse: true }));

    // Set MarketStatus
    oracleMiddleWare.setUpdater(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a, true);
    oracleMiddleWare.setUpdater(0x0578C797798Ae89b688Cd5676348344d7d0EC35E, true);

    bytes32[] memory _assetIds = new bytes32[](9);
    _assetIds[0] = usdcAssetId;
    _assetIds[1] = usdtAssetId;
    _assetIds[2] = daiAssetId;
    _assetIds[3] = wethAssetId;
    _assetIds[4] = wbtcAssetId;
    _assetIds[5] = glpAssetId;
    _assetIds[6] = appleAssetId;
    _assetIds[7] = jpyAssetId;
    _assetIds[8] = xauAssetId;

    uint8[] memory _statuses = new uint8[](9);
    _statuses[0] = 2;
    _statuses[1] = 2;
    _statuses[2] = 2;
    _statuses[3] = 2;
    _statuses[4] = 2;
    _statuses[5] = 2;
    _statuses[6] = 2;
    _statuses[7] = 2;
    _statuses[8] = 2;

    oracleMiddleWare.setMultipleMarketStatus(_assetIds, _statuses); // active

    // Set AssetPriceConfig
    uint32 _confidenceThresholdE6 = 100000; // 2.5% for test only
    uint32 _trustPriceAge = 365 days; // set max for test only

    AssetPythPriceData memory _data;

    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      _data = assetPythPriceDatas[i];

      // set PythId
      pythAdapter.setConfig(_data.assetId, _data.assetId, _data.inverse);
      ecoPyth.insertAssetId(_data.assetId);

      unchecked {
        ++i;
      }
    }

    oracleMiddleWare.setAssetPriceConfig(wethAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(wbtcAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(daiAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(usdcAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(usdtAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(appleAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(jpyAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(glpAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(xauAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));

    // GLP
    // oracleMiddleWare.setAssetPriceConfig(
    //   glpAssetId,
    //   _confidenceThresholdE6,
    //   _trustPriceAge,
    //   address(stakedGlpOracleAdapter)
    // );

    vm.stopBroadcast();
  }
}
