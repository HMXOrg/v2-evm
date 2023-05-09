// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

interface ILimitTradeHandler {
  /**
   * Errors
   */
  error ILimitTradeHandler_InvalidAddress();
  error ILimitTradeHandler_InsufficientExecutionFee();
  error ILimitTradeHandler_IncorrectValueTransfer();
  error ILimitTradeHandler_NotWhitelisted();
  error ILimitTradeHandler_BadSubAccountId();
  error ILimitTradeHandler_InvalidSender();
  error ILimitTradeHandler_NonExistentOrder();
  error ILimitTradeHandler_MarketIsClosed();
  error ILimitTradeHandler_InvalidPriceForExecution();
  error ILimitTradeHandler_WrongSizeDelta();
  error ILimitTradeHandler_UnknownOrderType();
  error ILimitTradeHandler_MaxExecutionFee();
  error ILimitTradeHandler_TriggerPriceBelowCurrentPrice();
  error ILimitTradeHandler_TriggerPriceAboveCurrentPrice();
  error ILimitTradeHandler_MarketOrderNoUpdate();
  error ILimitTradeHandler_LimitOrderConvertToMarketOrder();
  error ILimitTradeHandler_NotExecutionState();

  /**
   * Structs
   */
  struct LimitOrder {
    address account;
    address tpToken;
    bool triggerAboveThreshold;
    bool reduceOnly;
    int256 sizeDelta;
    uint8 subAccountId;
    uint256 marketIndex;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    uint256 executionFee;
    uint256 createdTimestamp;
  }

  struct OrderPointer {
    address account;
    uint256 index;
  }

  /**
   * States
   */
  function pyth() external returns (IEcoPyth);

  function tradeService() external returns (address);

  function minExecutionFee() external returns (uint256);

  function orderExecutors(address _address) external returns (bool);

  function limitOrdersIndex(address _address) external returns (uint256);

  function limitOrders(
    address _subAccount,
    uint256 _index
  )
    external
    returns (
      address account,
      address tpToken,
      bool triggerAboveThreshold,
      bool reduceOnly,
      int256 sizeDelta,
      uint8 subAccountId,
      uint256 marketIndex,
      uint256 triggerPrice,
      uint256 acceptablePrice,
      uint256 executionFee,
      uint256 createdTimestamp
    );

  /**
   * Functions
   */
  function createOrder(
    uint8 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    uint256 _acceptablePrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee,
    bool _reduceOnly,
    address _tpToken
  ) external payable;

  function executeOrder(
    address _account,
    uint8 _subAccountId,
    uint256 _orderIndex,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;

  function cancelOrder(uint8 _subAccountId, uint256 _orderIndex) external;

  function updateOrder(
    uint8 _subAccountId,
    uint256 _orderIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    bool _reduceOnly,
    address _tpToken
  ) external;

  function setPyth(address _pyth) external;

  function setTradeService(address _newTradeService) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  function setOrderExecutor(address _executor, bool _isAllow) external;

  function getAllActiveOrders(uint256 _limit, uint256 _offset) external view returns (LimitOrder[] memory _orders);

  function getMarketActiveOrders(uint256 _limit, uint256 _offset) external view returns (LimitOrder[] memory _orders);

  function getLimitActiveOrders(uint256 _limit, uint256 _offset) external view returns (LimitOrder[] memory _orders);
}
