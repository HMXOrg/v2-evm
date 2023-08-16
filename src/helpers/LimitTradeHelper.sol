// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

contract LimitTradeHelper is Ownable {
  error LimitTradeHelper_MarketMaxTradeSize();
  error LimitTradeHelper_MaxTradeSize();
  error LimitTradeHelper_MarketMaxPositionSize();
  error LimitTradeHelper_MaxPositionSize();

  event LogSetPositionSizeLimit(uint8 _assetClass, uint256 _positionSizeLimit, uint256 _tradeSizeLimit);
  event LogSetTradeLimitByMarket(uint256 _marketIndex, uint256 _positionSizeLimit, uint256 _tradeSizeLimit);

  ConfigStorage public configStorage;
  PerpStorage public perpStorage;
  mapping(uint8 assetClass => uint256 sizeLimit) public positionSizeLimit;
  mapping(uint8 assetClass => uint256 sizeLimit) public tradeSizeLimit;
  mapping(uint256 marketIndex => uint256 sizeLimit) public positionSizeLimitByMarket;
  mapping(uint256 marketIndex => uint256 sizeLimit) public tradeSizeLimitByMarket;

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

    // Check trade size limit as per market
    if (
      tradeSizeLimitByMarket[marketIndex] > 0 &&
      !reduceOnly &&
      HMXLib.abs(sizeDelta) > tradeSizeLimitByMarket[marketIndex]
    ) {
      if (isRevert) revert LimitTradeHelper_MarketMaxTradeSize();
      else return false;
    }

    // Check trade size limit as per asset class
    if (tradeSizeLimit[_assetClass] > 0 && !reduceOnly && HMXLib.abs(sizeDelta) > tradeSizeLimit[_assetClass]) {
      if (isRevert) revert LimitTradeHelper_MaxTradeSize();
      else return false;
    }

    // Check position size limit as per market
    if (
      positionSizeLimitByMarket[marketIndex] > 0 &&
      !reduceOnly &&
      HMXLib.abs(_positionSizeE30 + sizeDelta) > positionSizeLimitByMarket[marketIndex]
    ) {
      if (isRevert) revert LimitTradeHelper_MarketMaxPositionSize();
      else return false;
    }

    // Check position size limit as per asset class
    if (positionSizeLimit[_assetClass] > 0 && !reduceOnly) {
      if (HMXLib.abs(_positionSizeE30 + sizeDelta) > positionSizeLimit[_assetClass]) {
        if (isRevert) revert LimitTradeHelper_MaxPositionSize();
        else return false;
      }
    }
    return true;
  }

  function setLimitByMarketIndex(
    uint256[] calldata _marketIndexes,
    uint256[] calldata _positionSizeLimits,
    uint256[] calldata _tradeSizeLimits
  ) external onlyOwner {
    require(
      _marketIndexes.length == _positionSizeLimits.length && _positionSizeLimits.length == _tradeSizeLimits.length,
      "length not match"
    );
    uint256 _len = _marketIndexes.length;
    for (uint256 i = 0; i < _len; ) {
      positionSizeLimitByMarket[_marketIndexes[i]] = _positionSizeLimits[i];
      tradeSizeLimitByMarket[_marketIndexes[i]] = _tradeSizeLimits[i];

      emit LogSetTradeLimitByMarket(_marketIndexes[i], _positionSizeLimits[i], _tradeSizeLimits[i]);

      unchecked {
        ++i;
      }
    }
  }

  function setPositionSizeLimit(
    uint8 _assetClass,
    uint256 _positionSizeLimit,
    uint256 _tradeSizeLimit
  ) external onlyOwner {
    emit LogSetPositionSizeLimit(_assetClass, _positionSizeLimit, _tradeSizeLimit);
    positionSizeLimit[_assetClass] = _positionSizeLimit;
    tradeSizeLimit[_assetClass] = _tradeSizeLimit;
  }
}
