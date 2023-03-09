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
  error ILiquidityHandler_NotRefundState();
  error ILiquidityHandler_NotExecutionState();
  error ILiquidityHandler_NoOrder();

  /**
   * Struct
   */
  struct LiquidityOrder {
    address payable account;
    address token;
    uint256 amount;
    uint256 minOut;
    bool isAdd;
    uint256 executionFee;
    bool shouldUnwrap; // unwrap nativetoken when removeLiquidity
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
  ) external payable;

  function createRemoveLiquidityOrder(
    address _tokenSell,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable;

  function executeOrder(address _account, uint256 _orderIndex, bytes[] memory _priceData) external;

  function cancelLiquidityOrder(uint256 _orderIndex) external;

  function getLiquidityOrders(address _account) external view returns (LiquidityOrder[] memory);

  function lastOrderIndex(address _account) external view returns (uint256);

  function setOrderExecutor(address _executor, bool _isOk) external;

  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256);

  function refund(LiquidityOrder memory _order) external;
}
