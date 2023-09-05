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
   * States
   */
  function nextExecutionOrderIndex() external view returns (uint256);

  /**
   * Functions
   */
  function createAddLiquidityOrder(
    address _tokenBuy,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable returns (uint256);

  function createRemoveLiquidityOrder(
    address _tokenSell,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable returns (uint256);

  function executeOrder(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes32[] calldata _priceData,
    bytes32[] calldata _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;

  function cancelLiquidityOrder(uint256 _orderIndex) external;

  function getLiquidityOrders() external view returns (LiquidityOrder[] memory);

  function getLiquidityOrderLength() external view returns (uint256);

  function setOrderExecutor(address _executor, bool _isOk) external;

  function executeLiquidity(LiquidityOrder calldata _order) external returns (uint256);

  function getActiveLiquidityOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _liquidityOrders);

  function getExecutedLiquidityOrders(
    address _account,
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _liquidityOrders);

  function setMaxExecutionChunk(uint256 _maxExecutionChunk) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  function setHlpStaking(address _hlpStaking) external;
}
