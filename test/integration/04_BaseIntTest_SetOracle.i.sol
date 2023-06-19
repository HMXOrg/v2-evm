// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "@hmx-test/integration/03_BaseIntTest_SetMarkets.i.sol";

abstract contract BaseIntTest_SetOracle is BaseIntTest_SetMarkets {
  error BadArgs();

  bytes32 constant wethPriceId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 constant wbtcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 constant usdtPriceId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 constant daiPriceId = 0x0000000000000000000000000000000000000000000000000000000000000005;
  bytes32 constant applePriceId = 0x0000000000000000000000000000000000000000000000000000000000000006;
  bytes32 constant jpyPriceid = 0x0000000000000000000000000000000000000000000000000000000000000007;

  struct AssetPythPriceData {
    bytes32 assetId;
    bytes32 priceId;
    int64 price;
    int64 exponent;
    uint64 conf;
    bool inverse;
    int24 tickPrice;
  }

  AssetPythPriceData[] assetPythPriceDatas;
  /// @notice will change when a function called "setPrices" is used or when an object is created through a function called "constructor"
  bytes[] initialPriceFeedDatas;
  int24[] tickPrices;
  uint24[] publishTimeDiff;

  constructor() {
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: wethAssetId,
        priceId: wethPriceId,
        price: 1500 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 73135
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: wbtcAssetId,
        priceId: wbtcPriceId,
        price: 20000 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 99039
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: daiAssetId,
        priceId: daiPriceId,
        price: 1 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 0
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: usdcAssetId,
        priceId: usdcPriceId,
        price: 1 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 0
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: usdtAssetId,
        priceId: usdtPriceId,
        price: 1 * 1e8,
        exponent: -8,
        inverse: false,
        conf: 0,
        tickPrice: 0
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: appleAssetId,
        priceId: applePriceId,
        price: 152 * 1e5,
        exponent: -5,
        inverse: false,
        conf: 0,
        tickPrice: 50241
      })
    );
    assetPythPriceDatas.push(
      AssetPythPriceData({
        assetId: jpyAssetId,
        priceId: jpyPriceid,
        price: 136.123 * 1e3,
        exponent: -3,
        inverse: true,
        conf: 0,
        tickPrice: 49138
      })
    );

    // Set MarketStatus
    uint8 _marketActiveStatus = uint8(2);
    oracleMiddleWare.setUpdater(address(this), true); // Whitelist updater for oracleMiddleWare
    oracleMiddleWare.setUpdater(address(botHandler), true); // Whitelist updater for oracleMiddleWare
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

    //Setup pyth
    AssetPythPriceData memory _data;
    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      _data = assetPythPriceDatas[i];

      // set PythId
      pythAdapter.setConfig(_data.assetId, _data.assetId, _data.inverse);
      pyth.insertAssetId(_data.assetId);

      tickPrices.push(_data.tickPrice);
      publishTimeDiff.push(0);

      unchecked {
        ++i;
      }
    }

    // set UpdatePriceFeed
    pyth.setUpdater(address(this), true);
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(publishTimeDiff);
    pyth.updatePriceFeeds(priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
    skip(1);

    // Set AssetPriceConfig
    uint32 _confidenceThresholdE6 = 2500; // 2.5% for test only
    uint32 _trustPriceAge = type(uint32).max; // set max for test only
    oracleMiddleWare.setAssetPriceConfig(wethAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(wbtcAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(daiAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(usdcAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(usdtAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(appleAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
    oracleMiddleWare.setAssetPriceConfig(jpyAssetId, _confidenceThresholdE6, _trustPriceAge, address(pythAdapter));
  }

  /// @notice setPrices of pyth
  function setPrices(int24[] memory _tickPrices, uint24[] memory _publishTimeDiff) public {
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(_tickPrices);
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(_publishTimeDiff);
    pyth.updatePriceFeeds(priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
  }

  function updatePriceFeeds(int24[] memory _tickPrices, uint256 /* publishTime */) internal {
    bytes32[] memory priceUpdateData = pyth.buildPriceUpdateData(_tickPrices);
    uint24[] memory _publishTimeDiff = new uint24[](_tickPrices.length);
    for (uint256 i = 0; i < _tickPrices.length; i++) {
      _publishTimeDiff[i] = 0;
    }
    bytes32[] memory publishTimeUpdateData = pyth.buildPublishTimeUpdateData(_publishTimeDiff);
    pyth.updatePriceFeeds(priceUpdateData, publishTimeUpdateData, block.timestamp, keccak256("someEncodedVaas"));
  }

  // function _createPriceFeedUpdateData(
  //   bytes32 _assetId,
  //   int64 _price,
  //   uint64 _conf
  // ) internal view returns (bytes memory) {
  //   int64 pythDecimals;

  //   for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
  //     if (assetPythPriceDatas[i].assetId == _assetId) {
  //       pythDecimals = assetPythPriceDatas[i].exponent;
  //       break;
  //     }
  //     unchecked {
  //       ++i;
  //     }
  //   }

  //   (bytes32 _pythPriceId, ) = pythAdapter.configs(_assetId);

  //   bytes memory priceFeedData = pyth.createPriceFeedUpdateData(
  //     _pythPriceId,
  //     _price,
  //     _conf,
  //     int8(pythDecimals),
  //     _price,
  //     0,
  //     uint64(block.timestamp)
  //   );

  //   return priceFeedData;
  // }
}
