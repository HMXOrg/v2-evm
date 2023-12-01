// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IIntentHandler {
  error IntentHandler_NotEnoughCollateral();
  error IntentHandler_BadLength();
  error IntentHandler_OrderStale();
  error IntentHandler_Unauthorized();
  error IntentHandler_IntentReplay();
  error IntentHandler_InvalidAddress();

  event LogExecuteTradeOrderFail(
    address indexed account,
    uint256 indexed subAccountId,
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    bool triggerAboveThreshold,
    bool reduceOnly,
    address tpToken,
    bytes errMsg
  );
  event LogSetIntentExecutor(address executor, bool isAllow);

  enum Command {
    ExecuteTradeOrder
  }

  struct ExecuteTradeOrderVars {
    uint256 marketIndex;
    int256 sizeDelta;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    bool triggerAboveThreshold;
    bool reduceOnly;
    address tpToken;
    uint256 createdTimestamp;
    address subAccount;
    bytes32 positionId;
    bool positionIsLong;
    bool isNewPosition;
    bool isMarketOrder;
    address account;
    uint8 subAccountId;
  }

  struct ExecuteIntentVars {
    uint256 cmdsLength;
    address[] tpTokens;
    address mainAccount;
    uint8 subAccountId;
  }

  struct ExecuteIntentInputs {
    bytes32[] accountAndSubAccountIds;
    bytes32[] cmds;
    uint8[] v;
    bytes32[] r;
    bytes32[] s;
    bytes32[] priceData;
    bytes32[] publishTimeData;
    uint256 minPublishTime;
    bytes32 encodedVaas;
  }

  function executeIntent(ExecuteIntentInputs memory inputs) external;

  function setIntentExecutor(address _executor, bool _isAllow) external;
}
