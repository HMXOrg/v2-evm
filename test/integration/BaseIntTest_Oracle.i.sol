// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "@hmx-test/integration/BaseIntTest_SetMarkets.i.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract BaseIntTest_Oracle is BaseIntTest_SetMarkets {
  error BadArgs();

  bytes32 constant wethPriceId = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 constant wbtcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000002;
  bytes32 constant daiPriceId = 0x0000000000000000000000000000000000000000000000000000000000000003;
  bytes32 constant usdcPriceId = 0x0000000000000000000000000000000000000000000000000000000000000004;
  bytes32 constant usdtPriceId = 0x0000000000000000000000000000000000000000000000000000000000000005;
  bytes32 constant gmxPriceId = 0x0000000000000000000000000000000000000000000000000000000000000006;
  bytes32 constant applePriceId = 0x0000000000000000000000000000000000000000000000000000000000000007;
  bytes32 constant jpyPriceid = 0x0000000000000000000000000000000000000000000000000000000000000008;

  constructor() {
    //set PythId
    pythAdapter.setPythPriceId(wethAssetId, wethPriceId);
    pythAdapter.setPythPriceId(wbtcAssetId, wbtcPriceId);
    pythAdapter.setPythPriceId(daiAssetId, daiPriceId);
    pythAdapter.setPythPriceId(usdcAssetId, usdcPriceId);
    pythAdapter.setPythPriceId(usdtAssetId, usdtPriceId);
    pythAdapter.setPythPriceId(gmxAssetId, gmxPriceId);
    pythAdapter.setPythPriceId(appleAssetId, applePriceId);
    pythAdapter.setPythPriceId(jpyAssetId, jpyPriceid);

    // set UpdatePriceFeed
    // price will be multiply with 10** decimals in function
    _createPriceFeedUpdateData(wethAssetId, 1500);
    _createPriceFeedUpdateData(wbtcAssetId, 20000);
    _createPriceFeedUpdateData(daiAssetId, 1);
    _createPriceFeedUpdateData(usdcAssetId, 1);
    _createPriceFeedUpdateData(usdtAssetId, 1);
    _createPriceFeedUpdateData(gmxAssetId, 1);
    _createPriceFeedUpdateData(appleAssetId, 1);
    _createPriceFeedUpdateData(jpyAssetId, 1);
  }

  function setPrice(bytes32 _assetId, int64 _price) external {
    bytes[] memory _updateData = new bytes[](1);
    _updateData[0] = _createPriceFeedUpdateData(_assetId, _price);
    pyth.updatePriceFeeds(_updateData);
  }

  function setPrices(bytes32[] memory _assetIds, int64[] memory _prices) external {
    if (_assetIds.length != _prices.length) {
      revert BadArgs();
    }

    bytes[] memory _updateDatas = new bytes[](_assetIds.length);

    for (uint256 _i = 0; _i < _assetIds.length; ) {
      _updateDatas[_i] = _createPriceFeedUpdateData(_assetIds[_i], _prices[_i]);
      unchecked {
        ++_i;
      }
    }

    pyth.updatePriceFeeds(_updateDatas);
  }

  function _createPriceFeedUpdateData(bytes32 _assetId, int64 _price) internal returns (bytes memory) {
    IConfigStorage.AssetConfig memory assetConfig = configStorage.getAssetConfig(_assetId);

    int64 _decimalPow = int64(10) ** uint64(assetConfig.decimals);

    bytes memory priceFeedData = pyth.createPriceFeedUpdateData(
      pythAdapter.pythPriceIdOf(_assetId),
      _price * _decimalPow,
      0,
      -int8(assetConfig.decimals),
      _price * _decimalPow,
      0,
      uint64(block.timestamp)
    );

    return priceFeedData;
  }
}
