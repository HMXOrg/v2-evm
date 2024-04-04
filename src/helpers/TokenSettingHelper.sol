// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ITokenSettingHelper } from "@hmx/helpers/interfaces/ITokenSettingHelper.sol";

contract TokenSettingHelper is ITokenSettingHelper, ReentrancyGuardUpgradeable, OwnableUpgradeable {
  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  mapping(address user => address[] tokenSettings) public tokenSettingsBySubAccount;

  function initialize(address _vaultStorage, address _configStorage) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
  }

  function setTokenSettings(uint8 _subAccountId, address[] memory _tokenSettings) external nonReentrant {
    // Validate token settings
    uint256 _length = _tokenSettings.length;
    address[] memory _collateralTokens = configStorage.getCollateralTokens();
    for (uint256 i; i < _length; ) {
      bool _isCollateralToken = _findInCollateralTokens(_collateralTokens, _tokenSettings[i]);
      if (!_isCollateralToken) revert ITokenSettingHelper_NotCollateralToken();

      unchecked {
        ++i;
      }
    }

    address _subAccount = HMXLib.getSubAccount(msg.sender, _subAccountId);
    tokenSettingsBySubAccount[_subAccount] = _tokenSettings;
  }

  function _findInCollateralTokens(
    address[] memory _collateralTokens,
    address _token
  ) internal pure returns (bool isCollateralToken) {
    uint256 _length = _collateralTokens.length;
    for (uint256 i; i < _length; ) {
      if (_collateralTokens[i] == _token) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return isCollateralToken;
  }

  function getTokenSettingsBySubAccount(address _subAccount) external view returns (address[] memory) {
    return tokenSettingsBySubAccount[_subAccount];
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
