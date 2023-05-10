// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";

interface ICrossMarginHandler {
  /**
   * Errors
   */
  error ICrossMarginHandler_InvalidAddress();
  error ICrossMarginHandler_MismatchMsgValue();
  error ICrossMarginHandler_InCorrectValueTransfer();
  error ICrossMarginHandler_NotWhitelisted();
  error ICrossMarginHandler_InsufficientExecutionFee();
  error ICrossMarginHandler_NoOrder();
  error ICrossMarginHandler_NotOrderOwner();
  error ICrossMarginHandler_NotExecutionState();

  /**
   * Structs
   */
  struct WithdrawOrder {
    uint256 orderId;
    uint256 amount;
    uint256 executionFee;
    uint48 createdTimestamp;
    uint48 executedTimestamp;
    address payable account;
    address token;
    CrossMarginService crossMarginService;
    uint8 subAccountId;
    uint8 status; // 0 = pending, 1 = execution success, 2 = execution fail
    bool shouldUnwrap;
  }

  /**
   * States
   */

  function nextExecutionOrderIndex() external view returns (uint256);

  function crossMarginService() external returns (address);

  function pyth() external returns (address);

  /**
   * Functions
   */

  function depositCollateral(uint8 _subAccountId, address _token, uint256 _amount, bool _shouldWrap) external payable;

  function createWithdrawCollateralOrder(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable returns (uint256 _orderId);

  function executeOrder(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;

  function setCrossMarginService(address _address) external;

  function setPyth(address _address) external;

  function setOrderExecutor(address _executor, bool _isAllow) external;

  function convertSGlpCollateral(
    uint8 _subAccountId,
    address _tokenOut,
    uint256 _amountIn
  ) external returns (uint256 _amountOut);

  function getWithdrawOrders() external view returns (WithdrawOrder[] memory _withdrawOrder);

  function getWithdrawOrderLength() external view returns (uint256);

  function getActiveWithdrawOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrder);

  function getExecutedWithdrawOrders(
    address _account,
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrder);
}
