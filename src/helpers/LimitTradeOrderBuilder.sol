// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { WordCodec } from "@hmx/libraries/WordCodec.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract LimitTradeOrderBuilder {
  using WordCodec for bytes32;

  ConfigStorage configStorage;

  constructor(ConfigStorage configStorage_) {
    configStorage = configStorage_;
  }

  function buildAccountAndSubAccountId(
    address account,
    uint8 subAccountId
  ) external pure returns (bytes32 accountAndSubAccountId) {
    accountAndSubAccountId = accountAndSubAccountId.insertUint(uint160(account), 0, 160);
    accountAndSubAccountId = accountAndSubAccountId.insertUint(subAccountId, 160, 8);
  }

  function buildCreateOrder(
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    uint256 acceptablePrice,
    bool triggerAboveThreshold,
    uint256 executionFee,
    bool reduceOnly,
    address tpToken
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
    cmd = cmd.insertBool(triggerAboveThreshold, 183);
    // executionFee e8
    cmd = cmd.insertUint(executionFee / 1e10, 184, 27);
    // reduceOnly
    cmd = cmd.insertBool(reduceOnly, 211);
    // tpTokenIndex
    cmd = cmd.insertUint(_getTpTokenIndex(tpToken), 212, 7);
  }

  function buildUpdateOrder(
    uint256 orderIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    uint256 acceptablePrice,
    bool triggerAboveThreshold,
    bool reduceOnly,
    address tpToken
  ) external view returns (bytes32 cmd) {
    // command
    cmd = cmd.insertUint(1, 0, 3);
    // orderIndex
    cmd = cmd.insertUint(orderIndex, 3, 32);
    // sizeDelta e8
    cmd = cmd.insertInt(sizeDelta / 1e22, 35, 54);
    // triggerPrice e8
    cmd = cmd.insertUint(triggerPrice / 1e22, 89, 54);
    // acceptablePrice e8
    cmd = cmd.insertUint(acceptablePrice / 1e22, 143, 54);
    // triggerAboveThreshold
    cmd = cmd.insertBool(triggerAboveThreshold, 197);
    // reduceOnly
    cmd = cmd.insertBool(reduceOnly, 198);
    // tpTokenIndex
    cmd = cmd.insertUint(_getTpTokenIndex(tpToken), 199, 7);
  }

  function buildCancelOrder(uint256 orderIndex) external pure returns (bytes32 cmd) {
    // orderIndex
    cmd = cmd.insertUint(orderIndex, 3, 32);
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
