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
  error ILimitTradeHandler_MarketIsClosed();
  error ILimitTradeHandler_InvalidPriceForExecution();
  error ILimitTradeHandler_WrongSizeDelta();
  error ILimitTradeHandler_UnknownOrderType();
  error ILimitTradeHandler_MaxExecutionFee();
  error ILimitTradeHandler_TriggerPriceBelowCurrentPrice();
  error ILimitTradeHandler_TriggerPriceAboveCurrentPrice();

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
  }

  /**
   * States
   */

  function pyth() external returns (address);

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
      uint256 executionFee
    );

  /**
   * Setters
   */
  function setTradeService(address _newTradeService) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  function setOrderExecutor(address _executor, bool _isAllow) external;

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
    bytes[] memory _priceData
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
}
