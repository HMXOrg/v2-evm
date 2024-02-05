// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { WordCodec } from "@hmx/libraries/WordCodec.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { IIntentHandler } from "@hmx/handlers/interfaces/IIntentHandler.sol";

contract IntentBuilder {
  using WordCodec for bytes32;

  ConfigStorage configStorage;

  constructor(address configStorage_) {
    configStorage = ConfigStorage(configStorage_);
  }

  function buildAccountAndSubAccountId(
    address account,
    uint8 subAccountId
  ) public pure returns (bytes32 accountAndSubAccountId) {
    accountAndSubAccountId = accountAndSubAccountId.insertUint(uint160(account), 0, 160);
    accountAndSubAccountId = accountAndSubAccountId.insertUint(subAccountId, 160, 8);
  }

  function buildTradeOrder(
    IIntentHandler.TradeOrder memory tradeOrder
  ) external view returns (bytes32 accountAndSubAccountId, bytes32 cmd) {
    accountAndSubAccountId = buildAccountAndSubAccountId(tradeOrder.account, tradeOrder.subAccountId);
    // command
    cmd = cmd.insertUint(0, 0, 3);
    // marketIndex
    cmd = cmd.insertUint(tradeOrder.marketIndex, 3, 8);
    // sizeDelta e8
    cmd = cmd.insertInt(tradeOrder.sizeDelta / 1e22, 11, 54);
    // triggerPrice e8
    cmd = cmd.insertUint(tradeOrder.triggerPrice / 1e22, 65, 54);
    // acceptablePrice e8
    cmd = cmd.insertUint(tradeOrder.acceptablePrice / 1e22, 119, 54);
    // triggerAboveThreshold
    cmd = cmd.insertBool(tradeOrder.triggerAboveThreshold, 173);
    // reduceOnly
    cmd = cmd.insertBool(tradeOrder.reduceOnly, 174);
    // tpTokenIndex
    cmd = cmd.insertUint(_getTpTokenIndex(tradeOrder.tpToken), 175, 7);
    // createdTimestamp
    cmd = cmd.insertUint(tradeOrder.createdTimestamp, 182, 32);
    // expiryTimestamp
    cmd = cmd.insertUint(tradeOrder.expiryTimestamp, 214, 32);
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
