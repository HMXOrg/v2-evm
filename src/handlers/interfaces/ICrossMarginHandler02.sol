// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";

interface ICrossMarginHandler02 {
  /**
   * Errors
   */
  error ICrossMarginHandler02_InvalidAddress();
  error ICrossMarginHandler02_MismatchMsgValue();
  error ICrossMarginHandler02_InCorrectValueTransfer();
  error ICrossMarginHandler02_NotWhitelisted();
  error ICrossMarginHandler02_InsufficientExecutionFee();
  error ICrossMarginHandler02_NoOrder();
  error ICrossMarginHandler02_NotOrderOwner();
  error ICrossMarginHandler02_NotExecutionState();
  error ICrossMarginHandler02_NotWNativeToken();
  error ICrossMarginHandler02_Unauthorized();
  error ICrossMarginHandler02_BadAmount();
  error ICrossMarginHandler02_InvalidArraySize();
  error ICrossMarginHandler02_NonExistentOrder();

  /**
   * Structs
   */
  enum WithdrawOrderStatus {
    PENDING,
    SUCCESS,
    FAIL
  }

  struct WithdrawOrder {
    uint256 orderIndex;
    uint256 amount;
    uint256 executionFee;
    uint48 createdTimestamp;
    uint48 executedTimestamp;
    address payable account;
    address token;
    CrossMarginService crossMarginService;
    uint8 subAccountId;
    WithdrawOrderStatus status; // 0 = pending, 1 = execution success, 2 = execution fail
    bool shouldUnwrap;
  }

  /**
   * States
   */

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

  function executeOrders(
    address[] memory _accounts,
    uint8[] memory _subAccountIds,
    uint256[] memory _orderIndexes,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas,
    bool _isRevert
  ) external;

  function cancelWithdrawOrder(uint8 subAccountIds, uint256 orderIndex) external;

  function setCrossMarginService(address _address) external;

  function setPyth(address _address) external;

  function setOrderExecutor(address _executor, bool _isAllow) external;

  function setMinExecutionFee(uint256 _newMinExecutionFee) external;

  function getAllActiveOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrders);

  function getAllExecutedOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrders);

  function withdrawOrdersIndex(address _subAccount) external view returns (uint256 orderIndex);

  function getAllActiveOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _orders);

  function getAllExecutedOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _orders);
}
