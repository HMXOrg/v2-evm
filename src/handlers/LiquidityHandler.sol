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
import { IWNative } from "./interfaces/IWNative.sol";

/// @title LiquidityService
contract LiquidityHandler is ILiquidityHandler {
  mapping(address => LiquidityOrder[]) public liquidityOrders; // user address => all liquidityOrder
  mapping(address => uint256) startOrderIndex; //user address => startOrderIndex when execute

  address public weth;
  address liquidityService;

  constructor(address _weth, address _liquidityService) {
    weth = _weth;
    liquidityService = _liquidityService;
  }

  function createAddLiquidityOrder(
    address _tokenBuy,
    uint256 _amountIn,
    uint256 _minOut,
    bool _shouldWrap
  ) external payable {
    //1. convert native to WNative (including executionFee)
    _transferInETH();

    //@todo  if (_executionFee < minExecutionFee) revert InsufficientExecutionFee();  still need?
    if (_shouldWrap) {
      if (
        msg.value !=
        _amountIn +
          IConfigStorage(ILiquidityService(liquidityService).configStorage()).getLiquidityConfig().executionFeeAmount
      ) {
        revert ILiquidityHandler_InCorrectValueTransfer();
      }
    } else {
      if (
        msg.value !=
        IConfigStorage(ILiquidityService(liquidityService).configStorage()).getLiquidityConfig().executionFeeAmount
      ) revert ILiquidityHandler_InCorrectValueTransfer();

      ERC20(_tokenBuy).transferFrom(msg.sender, address(this), _amountIn);
    }

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenBuy,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: true,
        status: LiquidityOrderStatus.PROCESSING
      })
    );
    // @todo event
  }

  function createRemoveLiquidityOrder(address _tokenSell, uint256 _amountIn, uint256 _minOut) external payable {
    //convert native to WNative (including executionFee)
    _transferInETH();

    if (
      msg.value !=
      IConfigStorage(ILiquidityService(liquidityService).configStorage()).getLiquidityConfig().executionFeeAmount
    ) revert ILiquidityHandler_InCorrectValueTransfer();

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenSell,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: false,
        status: LiquidityOrderStatus.PROCESSING
      })
    );
    // @todo events
  }

  function cancelLiquidityOrder(LiquidityOrder[] memory _orders) external {
    for (uint256 i = 0; i < _orders.length; ) {
      LiquidityOrder memory _order = _orders[i];

      if (_order.status == LiquidityOrderStatus.PROCESSING) {
        liquidityOrders[_order.account][startOrderIndex[_order.account]].status = LiquidityOrderStatus.CANCELLED;
        userRefund(_order);
      }
      // @todo revert if _order status is not processing?
      unchecked {
        i++;
        startOrderIndex[_order.account]++;
      }
    }
  }

  // @todo onlyRefunder
  function userRefund(LiquidityOrder memory _order) internal {
    try this.refund(_order) {} catch Error(string memory reason) {
      revert ILiquidityHandler_InsufficientRefund();
    }
  }

  // @todo onlyRefunder
  function refund(LiquidityOrder memory _order) external {
    if (_order.token == weth) {
      _transferOutETHWithGasLimitIgnoreFail(_order.amount, _order.account);
    } else {
      ERC20(_order.token).transfer(_order.account, _order.amount);
    }
  }

  function executeOrders(LiquidityOrder[] memory _orders) external {
    for (uint256 i = 0; i < _orders.length; ) {
      LiquidityOrder memory _order = _orders[i];
      if (_order.status == LiquidityOrderStatus.PROCESSING) {
        ERC20(_order.token).approve(liquidityService, type(uint256).max);
        try this._executeLiquidity(_order) {
          liquidityOrders[_order.account][startOrderIndex[_order.account]].status = LiquidityOrderStatus.DONE;
        } catch Error(string memory reason) {
          liquidityOrders[_order.account][startOrderIndex[_order.account]].status = LiquidityOrderStatus.FAILED;
          userRefund(_order);
        }
      }
      unchecked {
        i++;
        startOrderIndex[_order.account]++;
      }
    }
  }

  // @todo try can be used only external need whitelisted
  function _executeLiquidity(LiquidityOrder memory _order) public returns (uint256) {
    return
      _order.isAdd
        ? ILiquidityService(liquidityService).addLiquidity(_order.account, _order.token, _order.amount, _order.minOut)
        : ILiquidityService(liquidityService).removeLiquidity(
          _order.account,
          _order.token,
          _order.amount,
          _order.minOut
        );
  }

  function _getOrder(address _lpProvider, uint256 _orderIndex) internal view returns (LiquidityOrder memory) {
    return liquidityOrders[_lpProvider][_orderIndex];
  }

  function _getPendingOrders(address lpProvider) external view returns (LiquidityOrder[] memory) {
    if (liquidityOrders[lpProvider].length == 0 || liquidityOrders[lpProvider].length == startOrderIndex[lpProvider]) {
      return new LiquidityOrder[](0);
    }

    LiquidityOrder[] memory _orders = liquidityOrders[lpProvider];
    LiquidityOrder[] memory pendingOrders = new LiquidityOrder[](
      liquidityOrders[lpProvider].length - startOrderIndex[lpProvider]
    );

    for (uint256 i = startOrderIndex[lpProvider]; i < _orders.length; ) {
      pendingOrders[i] = _orders[i];
      unchecked {
        i++;
      }
    }
    return pendingOrders;
  }

  function _transferInETH() private {
    if (msg.value != 0) {
      IWNative(weth).deposit{ value: msg.value }();
    }
  }

  function _transferOutETHWithGasLimitIgnoreFail(uint256 _amountOut, address payable _receiver) internal {
    IWNative(weth).withdraw(_amountOut);

    // use `send` instead of `transfer` to not revert whole transaction in case ETH transfer was failed
    // it has limit of 2300 gas
    // this is to avoid front-running
    _receiver.send(_amountOut);
  }
}
