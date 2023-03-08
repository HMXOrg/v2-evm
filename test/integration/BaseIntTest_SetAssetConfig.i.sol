// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "./BaseIntTest_SetMarkets.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetAssetConfig is BaseIntTest_SetMarkets {
  // @todo - setting discuss
  constructor() {
    _addAssetConfig(wethAssetId, address(weth), 18, false);

    _addAssetConfig(wbtcAssetId, address(wbtc), 8, false);

    _addAssetConfig(daiAssetId, address(dai), 18, true);

    _addAssetConfig(usdcAssetId, address(usdc), 6, true);

    _addAssetConfig(usdtAssetId, address(usdt), 6, true);

    _addAssetConfig(gmxAssetId, address(gmx), 18, false);
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
