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
  error IExt01Handler_InvalidArraySize();
  error IExt01Handler_NonExistentOrder();

  /**
   * Structs
   */
  enum OrderStatus {
    PENDING,
    SUCCESS,
    FAIL
  }

  struct GenericOrder {
    uint248 orderIndex;
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
    uint256 orderIndex;
    uint248 amount;
    address[] path;
    uint256 minToAmount;
    CrossMarginService crossMarginService;
  }

  struct CreateExtOrderParams {
    uint24 orderType;
    uint128 executionFee;
    address mainAccount;
    uint8 subAccountId;
    bytes data;
  }

  function createExtOrder(CreateExtOrderParams memory _params) external payable returns (uint256 _orderIndex);

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

  /**
   * Setters
   */
  function setOrderExecutor(address _executor, bool _isAllow) external;

  function setMinExecutionFee(uint24 _orderType, uint128 _minExecutionFee) external;

  function setDelegate(address _delegate) external;

  /**
    Getters
   */
  function getAllActiveOrders(uint256 _limit, uint256 _offset) external view returns (GenericOrder[] memory _orders);

  function getAllExecutedOrders(uint256 _limit, uint256 _offset) external view returns (GenericOrder[] memory _orders);

  function getAllActiveOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (GenericOrder[] memory _orders);

  function getAllExecutedOrdersBySubAccount(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (GenericOrder[] memory _orders);
}
