// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

contract LimitTradeHelper is Ownable {
  error MaxTradeSize();
  error MaxPositionSize();

  ConfigStorage public configStorage;
  PerpStorage public perpStorage;
  mapping(uint8 assetClass => uint256 sizeLimit) public positionSizeLimit;
  mapping(uint8 assetClass => uint256 sizeLimit) public tradeSizeLimit;

  constructor(address _configStorage, address _perpStorage) {
    configStorage = ConfigStorage(_configStorage);
    perpStorage = PerpStorage(_perpStorage);
  }

  function validate(
    address mainAccount,
    uint8 subAccountId,
    uint256 marketIndex,
    bool reduceOnly,
    int256 sizeDelta,
    bool isRevert
  ) external view returns (bool) {
    address _subAccount = HMXLib.getSubAccount(mainAccount, subAccountId);
    uint8 _assetClass = configStorage.getMarketConfigByIndex(marketIndex).assetClass;
    int256 _positionSizeE30 = perpStorage
      .getPositionById(HMXLib.getPositionId(_subAccount, marketIndex))
      .positionSizeE30;

    if (tradeSizeLimit[_assetClass] > 0 && !reduceOnly && HMXLib.abs(sizeDelta) > tradeSizeLimit[_assetClass]) {
      if (isRevert) revert MaxTradeSize();
      else return false;
    }

    if (positionSizeLimit[_assetClass] > 0 && !reduceOnly) {
      if (HMXLib.abs(_positionSizeE30 + sizeDelta) > positionSizeLimit[_assetClass]) {
        if (isRevert) revert MaxPositionSize();
        else return false;
      }
    }
    return true;
  }

  function setPositionSizeLimit(
    uint8 _assetClass,
    uint256 _positionSizeLimit,
    uint256 _tradeSizeLimit
  ) external onlyOwner {
    // Not logging event to save gas
    positionSizeLimit[_assetClass] = _positionSizeLimit;
    tradeSizeLimit[_assetClass] = _tradeSizeLimit;
  }
}
