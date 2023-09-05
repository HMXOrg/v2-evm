// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidityHandler02 {
  /**
   * Errors
   */
  error ILiquidityHandler02_InvalidSender();
  error ILiquidityHandler02_InvalidArraySize();
  error ILiquidityHandler02_InsufficientExecutionFee();
  error ILiquidityHandler02_InCorrectValueTransfer();
  error ILiquidityHandler02_InsufficientRefund();
  error ILiquidityHandler02_NotWhitelisted();
  error ILiquidityHandler02_InvalidAddress();
  error ILiquidityHandler02_NotExecutionState();
  error ILiquidityHandler02_NoOrder();
  error ILiquidityHandler02_NotOrderOwner();
  error ILiquidityHandler02_NotWNativeToken();
  error ILiquidityHandler02_Unauthorized();

  /**
   * Structs
   */
  enum LiquidityOrderStatus {
    PENDING,
    SUCCESS,
    FAIL
  }

  struct LiquidityOrder {
    uint256 orderIndex;
    uint256 amount;
    uint256 minOut;
    uint256 actualAmountOut;
    uint256 executionFee;
    address payable account;
    uint48 createdTimestamp;
    uint48 executedTimestamp;
    address token;
    bool isAdd;
    bool isNativeOut; // token Out for remove liquidity(!unwrap) and refund addLiquidity (shouldWrap) flag
    LiquidityOrderStatus status;
  }

  /**
   * Functions
   */
  function createAddLiquidityOrder(
    address _mainAccount,
    uint8 _subAccountId,
    address _tokenIn,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap
  ) external payable returns (uint256 _orderIndex);

  function createRemoveLiquidityOrder(
    address _mainAccount,
    uint8 _subAccountId,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _isNativeOut
  ) external payable returns (uint256 _orderIndex);

  function executeOrders(
    address[] memory _accounts,
    uint8[] memory _subAccountIds,
    uint256[] memory _orderIndexes,
    address payable _feeReceiver,
    bytes32[] calldata _priceData,
    bytes32[] calldata _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas,
    bool _isRevert
  ) external;

  function executeLiquidity(LiquidityOrder calldata _order) external returns (uint256);

  function cancelLiquidityOrder(address _mainAccount, uint8 _subAccountId, uint256 _orderIndex) external;

  /** Getters */
  function getAllActiveOrders(uint256 _limit, uint256 _offset) external view returns (LiquidityOrder[] memory _orders);

  function getAllExecutedOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _orders);

  function getAllActiveOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _orders);

  function getAllExecutedOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _orders);

  function setOrderExecutor(address _executor, bool _isOk) external;

  function setDelegate(address _delegate) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  function setHlpStaking(address _hlpStaking) external;
}
