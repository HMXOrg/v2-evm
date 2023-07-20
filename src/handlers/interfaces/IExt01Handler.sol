// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";

interface IExt01Handler {
  /**
   * Errors
   */
  error IExt01Handler_BadAddress();
  error IExt01Handler_BadAmount();
  error IExt01Handler_BadOrderType();
  error IExt01Handler_InsufficientExecutionFee();
  error IExt01Handler_InCorrectValueTransfer();
  error IExt01Handler_NoOrder();
  error IExt01Handler_SameFromToToken();
  error IExt01Handler_Unauthorized();

  /**
   * Structs
   */
  enum OrderStatus {
    PENDING,
    SUCCESS,
    FAIL
  }

  struct GenericOrder {
    uint248 orderId;
    OrderStatus status;
    uint48 createdTimestamp;
    uint48 executedTimestamp;
    uint24 orderType;
    uint128 executionFee;
    bytes rawOrder;
  }

  struct SwitchCollateralOrder {
    address primaryAccount;
    uint8 subAccountId;
    address fromToken;
    address toToken;
    uint256 fromAmount;
    uint256 minToAmount;
    bytes data;
    CrossMarginService crossMarginService;
  }

  struct CreateExtOrderParams {
    uint24 orderType;
    uint128 executionFee;
    bytes data;
  }

  function createExtOrder(CreateExtOrderParams memory _params) external payable returns (uint256 _orderId);

  function executeOrders(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;

  /**
   * Setters
   */
  function setOrderExecutor(address _executor, bool _isAllow) external;

  function setMinExecutionFee(uint24 _orderType, uint128 _minExecutionFee) external;
}
