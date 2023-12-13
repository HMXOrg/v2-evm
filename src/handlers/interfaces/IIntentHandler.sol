// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IIntentHandler {
  error IntentHandler_NotEnoughCollateral();
  error IntentHandler_BadLength();
  error IntentHandler_OrderStale();
  error IntentHandler_Unauthorized();
  error IntentHandler_IntentReplay();
  error IntentHandler_InvalidAddress();
  error IntenHandler_BadSignature();

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
    // +-----------------------+-----------+----------+-----------+---------------+
    // | Parameter Name        | Data Type | Decimals | Bit Range | No. of Bit(s) |
    // +-----------------------+-----------+----------+-----------+---------------+
    // | command               | uint      | 0        | 0 - 2     | 3             |
    // | marketIndex           | uint      | 0        | 3 - 10    | 8             |
    // | sizeDelta             | int       | 8        | 11 - 64   | 54            |
    // | triggerPrice          | uint      | 8        | 65 - 118  | 54            |
    // | acceptablePrice       | uint      | 8        | 119 - 172 | 54            |
    // | triggerAboveThreshold | bool      | N/A      | 173 - 173 | 1             |
    // | reduceOnly            | bool      | N/A      | 174 - 174 | 1             |
    // | tpTokenIndex          | uint      | 0        | 175 - 181 | 7             |
    // | createdTimestamp      | uint      | 0        | 182 - 213 | 32            |
    // | expiryTimestamp       | uint      | 0        | 214 - 245 | 32            |
    // +-----------------------+-----------+----------+-----------+---------------+
    ExecuteTradeOrder
  }

  struct ExecuteTradeOrderVars {
    TradeOrder order;
    address subAccount;
    bytes32 positionId;
    bool positionIsLong;
    bool isNewPosition;
    bool isMarketOrder;
  }

  struct TradeOrder {
    uint256 marketIndex;
    int256 sizeDelta;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    bool triggerAboveThreshold;
    bool reduceOnly;
    address tpToken;
    uint256 createdTimestamp;
    uint256 expiryTimestamp;
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
    bytes[] signatures;
    bytes32[] priceData;
    bytes32[] publishTimeData;
    uint256 minPublishTime;
    bytes32 encodedVaas;
  }

  function execute(ExecuteIntentInputs memory inputs) external;

  function setIntentExecutor(address _executor, bool _isAllow) external;

  function getDigest(IIntentHandler.TradeOrder memory _tradeOrder) external view returns (bytes32 _digest);
}
