// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidityHandler {
  /**
   * Errors
   */
  error ILiquidityHandler_InvalidSender();
  error ILiquidityHandler_InsufficientExecutionFee();
  error ILiquidityHandler_InCorrectValueTransfer();
  error ILiquidityHandler_InsufficientRefund();
  error ILiquidityHandler_NotWhitelisted();
  error ILiquidityHandler_InvalidAddress();
  error ILiquidityHandler_NotExecutionState();
  error ILiquidityHandler_NoOrder();
  error ILiquidityHandler_NotOrderOwner();

  /**
   * Struct
   */
  struct LiquidityOrder {
    address payable account;
    uint256 orderId;
    address token;
    uint256 amount;
    uint256 minOut;
    bool isAdd;
    uint256 executionFee;
    bool isNativeOut; // token Out for remove liquidity(!unwrap) and refund addLiquidity (shoulWrap) flag
  }

  /**
   * Core functions
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

  function executeOrder(uint256 endIndex, address payable feeReceiver, bytes[] memory _priceData) external;

  function cancelLiquidityOrder(uint256 _orderIndex) external;

  function getLiquidityOrders() external view returns (LiquidityOrder[] memory);

  function nextExecutionOrderIndex() external view returns (uint256);

  function setOrderExecutor(address _executor, bool _isOk) external;

  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256);

  function executionOrderFee() external view returns (uint256);
}
