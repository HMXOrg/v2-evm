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
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract CollateralReader is Ownable {
  using HMXLib for address;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  mapping(address ybToken => bool isYb) isYbToken;

  constructor(IVaultStorage _vaultStorage, IConfigStorage _configStorage) {
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
  }

  struct Collateral {
    address token;
    uint256 amount;
  }

  function setIsYbToken(address[] memory ybTokens, bool[] memory isYb) external onlyOwner {
    uint256 length = ybTokens.length;
    for (uint256 i = 0; i < length; i++) {
      isYbToken[ybTokens[i]] = isYb[i];
    }
  }

  function getCollaterals(
    address _account,
    uint8 _subAccountId
  ) external view returns (Collateral[] memory _collaterals) {
    _account = _account.getSubAccount(_subAccountId);
    address[] memory _collateralTokens = configStorage.getCollateralTokens();
    uint256 _len = _collateralTokens.length;
    _collaterals = new Collateral[](_len);
    address _baseTokenOfYb;
    for (uint256 i; i < _len; ) {
      _baseTokenOfYb = isYbToken[_collateralTokens[i]] ? IYBToken(_collateralTokens[i]).asset() : address(0);
      if (address(_baseTokenOfYb) != address(0)) {
        _collaterals[i].token = _baseTokenOfYb;
        _collaterals[i].amount = IYBToken(_collateralTokens[i]).previewRedeem(
          vaultStorage.traderBalances(_account, _collateralTokens[i])
        );
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
