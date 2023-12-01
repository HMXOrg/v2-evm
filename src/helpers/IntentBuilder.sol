// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { WordCodec } from "@hmx/libraries/WordCodec.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract IntentBuilder {
  using WordCodec for bytes32;

  ConfigStorage configStorage;

  constructor(address configStorage_) {
    configStorage = ConfigStorage(configStorage_);
  }

  function buildAccountAndSubAccountId(
    address account,
    uint8 subAccountId
  ) external pure returns (bytes32 accountAndSubAccountId) {
    accountAndSubAccountId = accountAndSubAccountId.insertUint(uint160(account), 0, 160);
    accountAndSubAccountId = accountAndSubAccountId.insertUint(subAccountId, 160, 8);
  }

  function buildTradeOrder(
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    uint256 acceptablePrice,
    bool triggerAboveThreshold,
    bool reduceOnly,
    address tpToken,
    uint256 createdTimestamp
  ) external view returns (bytes32 cmd) {
    // command
    cmd = cmd.insertUint(0, 0, 3);
    // marketIndex
    cmd = cmd.insertUint(marketIndex, 3, 8);
    // sizeDelta e8
    cmd = cmd.insertInt(sizeDelta / 1e22, 11, 54);
    // triggerPrice e8
    cmd = cmd.insertUint(triggerPrice / 1e22, 65, 54);
    // acceptablePrice e8
    cmd = cmd.insertUint(acceptablePrice / 1e22, 119, 54);
    // triggerAboveThreshold
    cmd = cmd.insertBool(triggerAboveThreshold, 173);
    // reduceOnly
    cmd = cmd.insertBool(reduceOnly, 174);
    // tpTokenIndex
    cmd = cmd.insertUint(_getTpTokenIndex(tpToken), 175, 7);
    // createdTimestamp
    cmd = cmd.insertUint(createdTimestamp, 182, 32);
  }

  function _getTpTokenIndex(address tpToken) internal view returns (uint256 index) {
    address[] memory tpTokens = configStorage.getHlpTokens();
    uint256 length = tpTokens.length;
    for (uint256 i; i < length; ) {
      if (tpToken == tpTokens[i]) {
        index = i;
        return index;
      }
      unchecked {
        ++i;
      }
    }
  }
}
