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
    address payable account;
    uint256 orderId;
    address token;
    uint256 amount;
    uint256 executionFee;
    bool shouldUnwrap;
    uint8 subAccountId;
    CrossMarginService crossMarginService;
  }

  /**
   * Functions
   */
  function crossMarginService() external returns (address);

  function pyth() external returns (address);

  function depositCollateral(uint8 _subAccountId, address _token, uint256 _amount, bool _shouldWrap) external payable;

  function setCrossMarginService(address _address) external;

  function setPyth(address _address) external;

  function setOrderExecutor(address _executor, bool _isAllow) external;

  function withdrawFundingFeeSurplus(address _stableToken, bytes[] memory _priceData) external payable;

  function createWithdrawCollateralOrder(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable returns (uint256 _orderId);

  function executeOrder(uint256 _endIndex, address payable _feeReceiver, bytes[] memory _priceData) external;
}
