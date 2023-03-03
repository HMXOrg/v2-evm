// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Owned } from "../base/Owned.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";

// contracts
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracle/OracleMiddleware.sol";

// interfaces
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IWNative } from "../interfaces/IWNative.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

/// @title LiquidityHandler
contract LiquidityHandler is Owned, ReentrancyGuard, ILiquidityHandler {
  using SafeERC20 for IERC20;

  /**
   * Events
   */
  event LogSetLiquidityService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogSetPyth(address oldPyth, address newPyth);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event LogCreateAddLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee
  );
  event LogCreateRemoveLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    bool shouldUnwrap
  );
  event LogExecuteLiquidityOrder(
    address payable account,
    address token,
    uint256 amount,
    uint256 minOut,
    bool isAdd,
    uint256 actualOut
  );
  event LogCancelLiquidityOrder(address payable account, address token, uint256 amount, uint256 minOut, bool isAdd);

  /**
   * States
   */

  address liquidityService; //liquidityService
  address pyth; //pyth
  uint256 public minExecutionFee; // minExecutionFee in tokenAmount unit
  bool isRefund; // order is refund (prevent direct call refund()
  bool isExecuting; // order is executing (prevent direct call executeLiquidity()
  mapping(address => LiquidityOrder[]) public liquidityOrders; // user address => all liquidityOrder
  mapping(address => uint256) public lastOrderIndex; // user address => lastOrderIndex of liquidityOrder
  mapping(address => bool) public orderExecutors; //address -> flag to execute

  constructor(address _liquidityService, address _pyth, uint256 _minExecutionFee) {
    liquidityService = _liquidityService;
    pyth = _pyth;
    minExecutionFee = _minExecutionFee;

    // slither-disable-next-line unused-return
    LiquidityService(_liquidityService).perpStorage();
    // slither-disable-next-line unused-return
    IPyth(_pyth).getValidTimePeriod();
  }

  /**
   * MODIFIER
   */

  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(LiquidityService(liquidityService).configStorage()).validateAcceptedLiquidityToken(_token);
    _;
  }

  modifier onlyOrderExecutor() {
    if (!orderExecutors[msg.sender]) revert ILiquidityHandler_NotWhitelisted();
    _;
  }

  receive() external payable {
    if (msg.sender != ConfigStorage(LiquidityService(liquidityService).configStorage()).weth())
      revert ILiquidityHandler_InvalidSender();
  }

  /**
   * Core Function
   */

  /// @notice Create a new AddLiquidity order
  /// @param _tokenIn address token in
  /// @param _amountIn amount token in (based on decimals)
  /// @param _minOut minPLP out
  /// @param _executionFee The execution fee of order
  /// @param _shouldWrap in case of sending native token
  function createAddLiquidityOrder(
    address _tokenIn,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap
  ) external payable nonReentrant onlyAcceptedToken(_tokenIn) {
    //1. convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (_shouldWrap) {
      if (msg.value != _amountIn + minExecutionFee) {
        revert ILiquidityHandler_InCorrectValueTransfer();
      }
    } else {
      if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();
      IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
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

    if (liquidityOrders[msg.sender].length > 1) {
      ++lastOrderIndex[msg.sender];
    }

    emit LogCreateAddLiquidityOrder(msg.sender, _tokenIn, _amountIn, _minOut, _executionFee);
  }

  /// @notice Create a new RemoveLiquidity order
  /// @param _tokenOut address token in
  /// @param _amountIn amount token in (based on decimals)
  /// @param _minOut minAmoutOut
  /// @param _executionFee The execution fee of order
  /// @param _shouldUnwrap in case of user need native token
  function createRemoveLiquidityOrder(
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable nonReentrant onlyAcceptedToken(_tokenOut) {
    //convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();

    IERC20(ConfigStorage(LiquidityService(liquidityService).configStorage()).plp()).safeTransferFrom(
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
    if (liquidityOrders[msg.sender].length > 1) {
      ++lastOrderIndex[msg.sender];
    }
    emit LogCreateRemoveLiquidityOrder(msg.sender, _tokenOut, _amountIn, _minOut, _executionFee, _shouldUnwrap);
  }

  /// @notice Cancel order
  /// @param _orderIndex orderIndex of user order
  function cancelLiquidityOrder(uint256 _orderIndex) external nonReentrant {
    _cancelLiquidityOrder(msg.sender, _orderIndex);
  }

  /// @notice Cancel order
  /// @param _account the primary account
  /// @param _orderIndex Order Index which could be retrieved from lastOrderIndex(address) beware in case of index is 0`
  function _cancelLiquidityOrder(address _account, uint256 _orderIndex) internal {
    // check _orderIndex not more than lastOrderIndex and data is removed?
    if (
      liquidityOrders[_account].length > _orderIndex && liquidityOrders[_account][_orderIndex].account != address(0)
    ) {
      LiquidityOrder memory order = liquidityOrders[_account][_orderIndex];
      isRefund = true;
      _userRefund(order);
      delete liquidityOrders[_account][_orderIndex];

      emit LogCancelLiquidityOrder(payable(_account), order.token, order.amount, order.minOut, order.isAdd);
      isRefund = false;
    } else {
      revert ILiquidityHandler_NoOrder();
    }
  }

  /// @notice Refund when cancel order, execution add failed
  /// @param _order order to execute
  function _userRefund(LiquidityOrder memory _order) internal {
    try this.refund(_order) {} catch Error(string memory) {
      revert ILiquidityHandler_InsufficientRefund();
    }
  }

  /// @notice refund order
  /// @dev this method has not be called directly
  /// @param _order order to execute
  // slither-disable-next-line
  function refund(LiquidityOrder memory _order) external {
    if (isRefund) {
      if (_order.token == ConfigStorage(LiquidityService(liquidityService).configStorage()).weth()) {
        _transferOutETH(_order.amount, _order.account);
      } else {
        IERC20(_order.token).safeTransfer(_order.account, _order.amount);
      }
    } else {
      revert ILiquidityHandler_NotRefundState();
    }
  }

  /// @notice orderExecutor pending order
  /// @param _account the primary account of user
  /// @param _orderIndex Order Index which could be retrieved from lastOrderIndex(address) beware in case of index is 0`
  /// @param _priceData Price data from Pyth to be used for updating the market prices
  // slither-disable-next-line reentrancy-eth
  function executeOrder(
    address _account,
    uint256 _orderIndex,
    bytes[] memory _priceData
  ) external nonReentrant onlyOrderExecutor {
    // Update price to Pyth
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    if (liquidityOrders[_account].length == 0) revert ILiquidityHandler_NoOrder();

    isExecuting = true;
    LiquidityOrder memory _order = liquidityOrders[_account][_orderIndex];
    try this.executeLiquidity(_order) returns (uint256 result) {
      emit LogExecuteLiquidityOrder(_order.account, _order.token, _order.amount, _order.minOut, _order.isAdd, result);
      delete liquidityOrders[_order.account][_orderIndex];
    } catch Error(string memory) {
      _userRefund(_order);
    }
    isExecuting = false;
  }

  /// @notice execute either addLiquidity or removeLiquidity
  /// @param _order order of executing
  // slither-disable-next-line
  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256) {
    if (isExecuting) {
      if (_order.isAdd) {
        IERC20(_order.token).safeTransfer(LiquidityService(liquidityService).vaultStorage(), _order.amount);
        return
          LiquidityService(liquidityService).addLiquidity(_order.account, _order.token, _order.amount, _order.minOut);
      } else {
        uint256 amountOut = LiquidityService(liquidityService).removeLiquidity(
          _order.account,
          _order.token,
          _order.amount,
          _order.minOut
        );
        if (_order.shouldUnwrap) {
          _transferOutETH(amountOut, payable(_order.account));
        } else {
          IERC20(_order.token).safeTransfer(_order.account, amountOut);
        }
        return amountOut;
      }
    } else {
      revert ILiquidityHandler_NotExecutionState();
    }
  }

  /// @notice Transfer in ETH from user to be used as execution fee
  /// @dev The received ETH will be wrapped into WETH and store in this contract for later use.
  function _transferInETH() private {
    IWNative(ConfigStorage(LiquidityService(liquidityService).configStorage()).weth()).deposit{ value: msg.value }();
  }

  /// @notice Transfer out ETH to the receiver
  /// @dev The stored WETH will be unwrapped and transfer as native token
  /// @param _amountOut Amount of ETH to be transferred
  /// @param _receiver The receiver of ETH in its native form. The receiver must be able to accept native token.
  function _transferOutETH(uint256 _amountOut, address _receiver) private {
    IWNative(ConfigStorage(LiquidityService(liquidityService).configStorage()).weth()).withdraw(_amountOut);
    // slither-disable-next-line arbitrary-send-eth
    payable(_receiver).transfer(_amountOut);
  }

  /**
   * GETTER
   */

  /// @notice get liquidity order
  /// @param _account the primary account of user
  function getLiquidityOrders(address _account) external view returns (LiquidityOrder[] memory _liquiditiyOrder) {
    return liquidityOrders[_account];
  }

  /**
   * SETTER
   */

  /// @notice setLiquidityService
  /// @param _newLiquidityService liquidityService address
  function setLiquidityService(address _newLiquidityService) external onlyOwner {
    if (_newLiquidityService == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetLiquidityService(liquidityService, _newLiquidityService);
    liquidityService = _newLiquidityService;
    LiquidityService(_newLiquidityService).vaultStorage();
  }

  /// @notice setMinExecutionFee
  /// @param _newMinExecutionFee minExecutionFee in ethers
  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  /// @notice setMinExecutionFee
  /// @param _executor address who will be executor
  /// @param _isAllow flag to allow to execute
  function setOrderExecutor(address _executor, bool _isAllow) external onlyOwner {
    orderExecutors[_executor] = _isAllow;
    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  /// @notice Set new Pyth contract address.
  /// @param _pyth New Pyth contract address.
  function setPyth(address _pyth) external onlyOwner {
    if (_pyth == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetPyth(pyth, _pyth);
    pyth = _pyth;

    // Sanity check
    IPyth(_pyth).getValidTimePeriod();
  }
}
