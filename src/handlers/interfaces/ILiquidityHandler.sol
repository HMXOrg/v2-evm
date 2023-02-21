// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILiquidityHandler {
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
    uint256 _executionFee
  ) external payable;

  function executeOrders(LiquidityOrder[] memory _orders, bytes[] memory _priceData) external;

  function cancelLiquidityOrder(LiquidityOrder[] memory _orders) external;

  struct LiquidityOrder {
    address payable account;
    address token;
    uint256 amount;
    uint256 minOut;
    bool isAdd;
    LiquidityOrderStatus status;
  }

  enum LiquidityOrderStatus {
    PROCESSING,
    DONE,
    FAILED,
    CANCELLED
  }

  error ILiquidityHandler_InvalidSender();
  error ILiquidityHandler_InsufficientExecutionFee();
  error ILiquidityHandler_InCorrectValueTransfer();
  error ILiquidityHandler_InsufficientRefund();
  error ILiquidityHandler_NotWhitelisted();
  error ILiquidityHandler_InvalidAddress();
}
