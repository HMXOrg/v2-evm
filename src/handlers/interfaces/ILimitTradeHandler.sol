// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

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
  error ILimitTradeHandler_MarketIsClose();
  error ILimitTradeHandler_InvalidPriceForExecution();
  error ILimitTradeHandler_WrongSizeDelta();

  /**
   * Enumerators
   */
  enum OrderType {
    INCREASE,
    DECREASE
  }

  /**
   * Structs
   */
  struct IncreaseOrder {
    address account;
    uint256 subAccountId;
    uint256 marketIndex;
    int256 sizeDelta;
    bool isLong;
    uint256 triggerPrice;
    bool triggerAboveThreshold;
    uint256 executionFee;
  }
  struct DecreaseOrder {
    address account;
    uint256 subAccountId;
    uint256 marketIndex;
    uint256 sizeDelta;
    bool isLong;
    uint256 triggerPrice;
    bool triggerAboveThreshold;
    uint256 executionFee;
  }

  /**
   * Setters
   */
  function setTradeService(address _newTradeService) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  /**
   * Functions
   */
  function createOrder(
    OrderType _orderType,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee
  ) external payable;

  function executeOrder(
    OrderType _orderType,
    address _account,
    uint256 _subAccountId,
    uint256 _orderIndex,
    address payable _feeReceiver,
    bytes[] memory _priceData
  ) external;

  function cancelOrder(OrderType _orderType, uint256 _subAccountId, uint256 _orderIndex) external;

  function updateOrder(
    OrderType _orderType,
    uint256 _subAccountId,
    uint256 _orderIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold
  ) external;

  function validatePositionOrderPrice(
    bool _triggerAboveThreshold,
    uint256 _triggerPrice,
    uint256 _marketIndex,
    bool _maximizePrice,
    bool _revertOnError
  ) external view returns (uint256, bool);
}
