// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_SetCollateralTokens } from "@hmx-test/integration/05_BaseIntTest_SetCollateralTokens.i.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetAssetConfigs is BaseIntTest_SetCollateralTokens {
  constructor() {
    bytes32[] memory _assetIds = new bytes32[](5);
    _assetIds[0] = ybethAssetId;
    _assetIds[1] = wbtcAssetId;
    _assetIds[2] = ybusdbAssetId;
    _assetIds[3] = usdcAssetId;
    _assetIds[4] = usdtAssetId;

    IConfigStorage.AssetConfig[] memory _newConfigs = new IConfigStorage.AssetConfig[](5);
    _newConfigs[0] = IConfigStorage.AssetConfig({
      tokenAddress: address(ybeth),
      assetId: ybethAssetId,
      decimals: 18,
      isStableCoin: false
    });
    _newConfigs[1] = IConfigStorage.AssetConfig({
      tokenAddress: address(wbtc),
      assetId: wbtcAssetId,
      decimals: 8,
      isStableCoin: false
    });
    _newConfigs[2] = IConfigStorage.AssetConfig({
      tokenAddress: address(ybusdb),
      assetId: ybusdbAssetId,
      decimals: 18,
      isStableCoin: true
    });
    _newConfigs[3] = IConfigStorage.AssetConfig({
      tokenAddress: address(usdc),
      assetId: usdcAssetId,
      decimals: 6,
      isStableCoin: true
    });
    _newConfigs[4] = IConfigStorage.AssetConfig({
      tokenAddress: address(usdt),
      assetId: usdtAssetId,
      decimals: 6,
      isStableCoin: true
    });
    configStorage.setAssetConfigs(_assetIds, _newConfigs);
  }
}
