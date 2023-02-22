// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ILiquidityHandler } from "./interfaces/ILiquidityHandler.sol";
import { ILiquidityService } from "../services/interfaces/ILiquidityService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { PLPv2 } from "../contracts/PLPv2.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { IWNative } from "../interfaces/IWNative.sol";
import { IPyth } from "../../lib/pyth-sdk-solidity/IPyth.sol";
import { console } from "../../lib/forge-std/src/console.sol";

import { Owned } from "../base/Owned.sol";

/// @title LiquidityService
contract LiquidityHandler is Owned, ILiquidityHandler {
  event LogSetLiquidityService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event CreateAddLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee
  );
  event CreateRemoveLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee
  );
  event ExecuteLiquidityOrder(
    address payable account,
    address token,
    uint256 amount,
    uint256 minOut,
    bool isAdd,
    uint256 actualOut
  );
  event CancelLiquidityOrder(address payable account, address token, uint256 amount, uint256 minOut, bool isAdd);

  mapping(address => LiquidityOrder[]) public liquidityOrders; // user address => all liquidityOrder
  mapping(address => uint256) public lastOrderIndex; // user address => lastOrderIndex of liquidityOrder

  bool isRefund;
  bool isExecuting;
  mapping(address => bool) public orderExecutors; //address => isExecutor?

  address liquidityService;
  address pyth;

  uint256 public minExecutionFee;

  constructor(address _liquidityService, address _pyth, uint256 _minExecutionFee) {
    liquidityService = _liquidityService;
    pyth = _pyth;
    minExecutionFee = _minExecutionFee;
  }

  receive() external payable {
    if (msg.sender != IConfigStorage(ILiquidityService(liquidityService).configStorage()).weth())
      revert ILiquidityHandler_InvalidSender();
  }

  /**
   * MODIFIER
   */

  modifier onlyAcceptedToken(address _token) {
    IConfigStorage(ILiquidityService(liquidityService).configStorage()).validateAcceptedLiquidityToken(_token);
    _;
  }

  // Only whitelisted addresses can be able to execute limit orders
  modifier onlyOrderExecutor() {
    if (!orderExecutors[msg.sender]) revert ILiquidityHandler_NotWhitelisted();
    _;
  }

  /**
   * GETTER
   */

  function getLiquidityOrders(address _account) external view returns (LiquidityOrder[] memory) {
    return liquidityOrders[_account];
  }

  /**
   * SETTER
   */
  function setLiquidityService(address _newLiquidityService) external onlyOwner {
    if (_newLiquidityService == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetLiquidityService(liquidityService, _newLiquidityService);
    liquidityService = _newLiquidityService;
  }

  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  function setOrderExecutor(address _executor, bool _isAllow) external onlyOwner {
    orderExecutors[_executor] = _isAllow;
    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  /**
   * Core Function
   */

  function createAddLiquidityOrder(
    address _tokenIn,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap
  ) external payable onlyAcceptedToken(_tokenIn) {
    //1. convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (_shouldWrap) {
      if (msg.value != _amountIn + minExecutionFee) {
        revert ILiquidityHandler_InCorrectValueTransfer();
      }
    } else {
      if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();
      ERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
    }

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenIn,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: true,
        shouldUnwrap: false
      })
    );

    ++lastOrderIndex[msg.sender];

    emit CreateAddLiquidityOrder(msg.sender, _tokenIn, _amountIn, _minOut, _executionFee);
  }

  /// @notice createOrder for removeLiquidity
  function createRemoveLiquidityOrder(
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable onlyAcceptedToken(_tokenOut) {
    //convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();

    ERC20(IConfigStorage(ILiquidityService(liquidityService).configStorage()).plp()).transferFrom(
      msg.sender,
      address(this),
      _amountIn
    );

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenOut,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: false,
        shouldUnwrap: _shouldUnwrap
      })
    );
    ++lastOrderIndex[msg.sender];

    emit CreateRemoveLiquidityOrder(msg.sender, _tokenOut, _amountIn, _minOut, _executionFee);
  }

  /// @notice if user deposit native and failed, it will return to wrappedToken
  function cancelLiquidityOrder(uint256 _orderIndex) external {
    _cancelLiquidityOrder(msg.sender, _orderIndex);
  }

  function _cancelLiquidityOrder(address _account, uint256 _orderIndex) internal {
    // check _orderIndex not more than lastOrderIndex and data is removed?
    if (lastOrderIndex[_account] > _orderIndex && liquidityOrders[_account][_orderIndex].account != address(0)) {
      LiquidityOrder memory order = liquidityOrders[_account][_orderIndex];
      isRefund = true;
      _userRefund(order);
      delete liquidityOrders[_account][_orderIndex];

      emit CancelLiquidityOrder(payable(_account), order.token, order.amount, order.minOut, order.isAdd);
      isRefund = false;
    } else {
      revert ILiquidityHandler_NoOrder();
    }
  }

  function _userRefund(LiquidityOrder memory _order) internal {
    try this.refund(_order) {} catch Error(string memory reason) {
      revert ILiquidityHandler_InsufficientRefund();
    }
  }

  function refund(LiquidityOrder memory _order) external {
    if (isRefund) {
      if (_order.token == IConfigStorage(ILiquidityService(liquidityService).configStorage()).weth()) {
        _transferOutETHWithGasLimitIgnoreFail(_order.amount, _order.account);
      } else {
        ERC20(_order.token).transfer(_order.account, _order.amount);
      }
    } else {
      revert ILiquidityHandler_NotRefundState();
    }
  }

  function executeOrders(LiquidityOrder[] memory _orders, bytes[] memory _priceData) external onlyOrderExecutor {
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    isExecuting = true;
    for (uint256 i = 0; i < _orders.length; ) {
      LiquidityOrder memory _order = _orders[i];
      if (liquidityOrders[_order.account].length > 0) {
        try this.executeLiquidity(_order) returns (uint256 result) {
          emit ExecuteLiquidityOrder(_order.account, _order.token, _order.amount, _order.minOut, _order.isAdd, result);
        } catch Error(string memory reason) {
          _userRefund(_order);
        }
        delete liquidityOrders[_order.account][0];
      }

      unchecked {
        ++i;
      }
    }
    isExecuting = false;
  }

  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256) {
    if (isExecuting) {
      if (_order.isAdd) {
        ERC20(_order.token).transfer(ILiquidityService(liquidityService).vaultStorage(), _order.amount);
        return
          ILiquidityService(liquidityService).addLiquidity(_order.account, _order.token, _order.amount, _order.minOut);
      } else {
        uint256 amountOut = ILiquidityService(liquidityService).removeLiquidity(
          _order.account,
          _order.token,
          _order.amount,
          _order.minOut
        );
        if (_order.shouldUnwrap) {
          _transferOutETHWithGasLimitIgnoreFail(amountOut, payable(_order.account));
        }
      }
    } else {
      revert ILiquidityHandler_NotExecutionState();
    }
  }

  function _transferInETH() private {
    if (msg.value != 0) {
      IWNative(IConfigStorage(ILiquidityService(liquidityService).configStorage()).weth()).deposit{
        value: msg.value
      }();
    }
  }

  function _transferOutETHWithGasLimitIgnoreFail(uint256 _amountOut, address payable _receiver) internal {
    IWNative(IConfigStorage(ILiquidityService(liquidityService).configStorage()).weth()).withdraw(_amountOut);

    // use `send` instead of `transfer` to not revert whole transaction in case ETH transfer was failed
    // it has limit of 2300 gas
    // this is to avoid front-running
    _receiver.send(_amountOut);
  }
}
