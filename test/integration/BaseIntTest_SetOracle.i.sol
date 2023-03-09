// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "@hmx-test/integration/BaseIntTest_SetMarkets.i.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { console } from "forge-std/console.sol";

abstract contract BaseIntTest_SetOracle is BaseIntTest_SetMarkets {
  error BadArgs();

  bytes32 constant wethPriceId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 constant wbtcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 constant daiPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 constant usdtPriceId = 0x0000000000000000000000000000000000000000000000000000000000000005;
  bytes32 constant gmxPriceId = 0x0000000000000000000000000000000000000000000000000000000000000006;
  bytes32 constant applePriceId = 0x0000000000000000000000000000000000000000000000000000000000000007;
  bytes32 constant jpyPriceid = 0x0000000000000000000000000000000000000000000000000000000000000008;

  struct AssetPythPriceData {
    bytes32 assetId;
    bytes32 priceId;
    int64 price;
    int64 pythDecimals;
  }

  AssetPythPriceData[] assetPythPriceDatas;
  /// @notice will change when a function called "setPrices" is used or when an object is created through a function called "constructor"
  bytes[] initialPriceFeedDatas;

  constructor() {
    assetPythPriceDatas.push(AssetPythPriceData(wethAssetId, wethPriceId, 1500, -8));
    assetPythPriceDatas.push(AssetPythPriceData(wbtcAssetId, wbtcPriceId, 20000, -8));
    assetPythPriceDatas.push(AssetPythPriceData(daiAssetId, daiPriceId, 1, -8));
    assetPythPriceDatas.push(AssetPythPriceData(usdcAssetId, usdcPriceId, 1, -8));
    assetPythPriceDatas.push(AssetPythPriceData(usdtAssetId, usdtPriceId, 1, -8));
    assetPythPriceDatas.push(AssetPythPriceData(gmxAssetId, gmxPriceId, 1, -8));
    assetPythPriceDatas.push(AssetPythPriceData(appleAssetId, applePriceId, 1, -5));
    assetPythPriceDatas.push(AssetPythPriceData(jpyAssetId, jpyPriceid, 1, -3));

    // set MarketStatus
    oracleMiddleWare.setUpdater(address(this), true); // Whitelist updater for oracleMiddleWare
    oracleMiddleWare.setMarketStatus(wethAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(wbtcAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(daiAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(usdcAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(usdtAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(gmxAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(appleAssetId, uint8(2)); // active
    oracleMiddleWare.setMarketStatus(jpyAssetId, uint8(2)); // active

    // set AssetPriceConfig
    oracleMiddleWare.setAssetPriceConfig(wethAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(wbtcAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(daiAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(usdcAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(usdtAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(gmxAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(appleAssetId, 1e6, 60);
    oracleMiddleWare.setAssetPriceConfig(jpyAssetId, 1e6, 60);

    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      AssetPythPriceData memory _data = assetPythPriceDatas[i];
      // set PythId
      pythAdapter.setPythPriceId(_data.assetId, _data.assetId);
      // set UpdatePriceFeed
      initialPriceFeedDatas.push(_createPriceFeedUpdateData(_data.assetId, _data.price));

      unchecked {
        ++i;
      }
    }
    uint256 fee = pyth.getUpdateFee(initialPriceFeedDatas);
    vm.deal(address(this), fee);
    pyth.updatePriceFeeds{ value: fee }(initialPriceFeedDatas);
  }

  /// @notice setPrices of pyth
  /// @param _assetIds assetIds array
  /// @param _prices price of each asset
  /// @return _newDatas bytes[] of setting
  function setPrices(bytes32[] memory _assetIds, int64[] memory _prices) public returns (bytes[] memory _newDatas) {
    if (_assetIds.length != _prices.length) {
      revert BadArgs();
    }

    _newDatas = new bytes[](_assetIds.length);

    for (uint256 i = 0; i < _assetIds.length; ) {
      _newDatas[i] = (_createPriceFeedUpdateData(_assetIds[i], _prices[i]));
      unchecked {
        ++i;
      }
    }

    uint256 fee = pyth.getUpdateFee(_newDatas);
    vm.deal(address(this), fee);
    pyth.updatePriceFeeds{ value: fee }(_newDatas);
    return _newDatas;
  }

  function _createPriceFeedUpdateData(bytes32 _assetId, int64 _price) internal returns (bytes memory) {
    int64 decimals;

    for (uint256 i = 0; i < assetPythPriceDatas.length; ) {
      if (assetPythPriceDatas[i].assetId == _assetId) {
        decimals = assetPythPriceDatas[i].pythDecimals;
        break;
      }
      unchecked {
        ++i;
      }
    }

    int64 _decimalPow = int64(10) ** uint64(-decimals);

    bytes memory priceFeedData = pyth.createPriceFeedUpdateData(
      pythAdapter.pythPriceIdOf(_assetId),
      _price * _decimalPow,
      0,
      int8(decimals),
      _price * _decimalPow,
      0,
      uint64(block.timestamp)
    );

    return priceFeedData;
  }
}
