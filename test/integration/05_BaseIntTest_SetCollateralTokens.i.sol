// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseIntTest_SetOracle } from "./04_BaseIntTest_SetOracle.i.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

abstract contract BaseIntTest_SetCollateralTokens is BaseIntTest_SetOracle {
  constructor() {
    // collateralFactorBPS = 80%
    _addCollateralConfig(sglpAssetId, 8000, true, address(0));
    // collateralFactorBPS = 80%
    _addCollateralConfig(ybethAssetId, 8000, true, address(0));
    // collateralFactorBPS = 80%
    _addCollateralConfig(wbtcAssetId, 8000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(ybusdbAssetId, 10000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(usdcAssetId, 10000, true, address(0));
    // collateralFactorBPS = 100%
    _addCollateralConfig(usdtAssetId, 10000, true, address(0));
  }

  /// @notice to add collateral config with some default value
  /// @param _assetId Asset's ID
  /// @param _collateralFactorBPS token reliability factor to calculate buying power, 1e4 = 100%
  /// @param _isAccepted accepted to deposit as collateral
  /// @param _settleStrategy determine token will be settled for NON HLP collateral, e.g. aUSDC redeemed as USDC
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
