// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// Internal Libs
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// Interfaces
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IYBToken } from "@hmx/interfaces/blast/IYBToken.sol";

contract CollateralReader {
  using HMXLib for address;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;

  constructor(IVaultStorage _vaultStorage, IConfigStorage _configStorage) {
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
  }

  struct Collateral {
    address token;
    uint256 amount;
  }

  function getCollaterals(
    address _account,
    uint8 _subAccountId
  ) external view returns (Collateral[] memory _collaterals) {
    _account = _account.getSubAccount(_subAccountId);
    address[] memory _collateralTokens = configStorage.getCollateralTokens();
    uint256 _len = _collateralTokens.length;
    _collaterals = new Collateral[](_len);
    IYBToken _yb;
    for (uint256 i; i < _len; ) {
      _yb = IYBToken(configStorage.ybTokenOf(_collateralTokens[i]));
      if (address(_yb) != address(0)) {
        _collaterals[i].token = _yb.asset();
        _collaterals[i].amount = _yb.previewRedeem(vaultStorage.traderBalances(_account, _collateralTokens[i]));
      } else {
        _collaterals[i].token = _collateralTokens[i];
        _collaterals[i].amount = vaultStorage.traderBalances(_account, _collateralTokens[i]);
      }
      unchecked {
        ++i;
      }
    }
  }
}
