// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_SetCollateralTokens } from "@hmx-test/integration/05_BaseIntTest_SetCollateralTokens.i.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetAssetConfigs is BaseIntTest_SetCollateralTokens {
  constructor() {
    _addAssetConfig(ybethAssetId, address(ybeth), 18, false);
    _addAssetConfig(wbtcAssetId, address(wbtc), 8, false);
    _addAssetConfig(ybusdbAssetId, address(ybusdb), 18, true);
    _addAssetConfig(usdcAssetId, address(usdc), 6, true);
    _addAssetConfig(usdtAssetId, address(usdt), 6, true);
  }

  /// @notice to add asset config with some default value
  /// @param _assetId Asset's ID
  /// @param _token token address
  /// @param _decimals decimal of token
  /// @param _isStableCoin is stable coin
  function _addAssetConfig(bytes32 _assetId, address _token, uint8 _decimals, bool _isStableCoin) private {
    IConfigStorage.AssetConfig memory _assetConfig;

    _assetConfig.assetId = _assetId;
    _assetConfig.tokenAddress = _token;
    _assetConfig.decimals = _decimals;
    _assetConfig.isStableCoin = _isStableCoin;

    configStorage.setAssetConfig(_assetId, _assetConfig);
  }
}
