// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseIntTest_SetMarkets } from "./BaseIntTest_SetMarkets.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetCollaterals is BaseIntTest_SetMarkets {
  // @todo - setting discuss
  constructor() {
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(wethAssetId, 0.8 * 1e4, true, address(0));
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(wbtcAssetId, 0.8 * 1e4, true, address(0));
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(daiAssetId, 0.8 * 1e4, true, address(0));
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(usdcAssetId, 0.8 * 1e4, true, address(0));
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(usdtAssetId, 0.8 * 1e4, true, address(0));
    // collateralFactorBPS = 0.8%
    _addCollateralConfig(gmxAssetId, 0.8 * 1e4, true, address(0));
  }

  /// @notice to add collateral config with some default value
  /// @param _assetId Asset's ID
  /// @param _collateralFactorBPS token reliability factor to calculate buying power, 1e4 = 100%
  /// @param _isAccepted accepted to deposit as collateral
  /// @param _settleStrategy determine token will be settled for NON PLP collateral, e.g. aUSDC redeemed as USDC
  function _addCollateralConfig(
    bytes32 _assetId,
    uint32 _collateralFactorBPS,
    bool _isAccepted,
    address _settleStrategy
  ) private {
    IConfigStorage.CollateralTokenConfig memory _collatTokenConfig;

    _collatTokenConfig.collateralFactorBPS = _collateralFactorBPS;
    _collatTokenConfig.accepted = _isAccepted;
    _collatTokenConfig.settleStrategy = _settleStrategy;

    configStorage.setCollateralTokenConfig(_assetId, _collatTokenConfig);
  }
}
