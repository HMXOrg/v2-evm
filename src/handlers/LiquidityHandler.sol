// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// contracts
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

// interfaces
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IWNative } from "../interfaces/IWNative.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

/// @title LiquidityHandler
/// @notice This contract handles liquidity orders for adding or removing liquidity from a pool
contract LiquidityHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, ILiquidityHandler {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * Events
   */
  event LogSetLiquidityService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogSetPyth(address oldPyth, address newPyth);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event LogCreateAddLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed tokenIn,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    uint256 orderTimestamp
  );
  event LogCreateRemoveLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    bool isNativeOut,
    uint256 orderTimestamp
  );
  event LogExecuteLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed token,
    uint256 amount,
    uint256 minOut,
    bool isAdd,
    uint256 actualOut
  );
  event LogCancelLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed token,
    uint256 amount,
    uint256 minOut,
    bool isAdd
  );
  event LogRefund(
    address indexed account,
    uint256 indexed orderId,
    address indexed token,
    uint256 amount,
    bool isNativeOut
  );

  /**
   * States
   */
  address public liquidityService; //liquidityService
  address public pyth; //pyth
  uint256 public nextExecutionOrderIndex; // the index of the next liquidity order that should be executed
  uint256 public minExecutionOrderFee; // minimum execution order fee in native token amount
  bool private isExecuting; // order is executing (prevent direct call executeLiquidity()

  LiquidityOrder[] public liquidityOrders; // all pending liquidity orders
  mapping(address => bool) public orderExecutors; // address -> whitelist executors

  /// @notice Initializes the LiquidityHandler contract with the provided configuration parameters.
  /// @param _liquidityService Address of the LiquidityService contract.
  /// @param _pyth Address of the Pyth contract.
  /// @param _minExecutionOrderFee Minimum execution fee for execute order.
  function initialize(address _liquidityService, address _pyth, uint256 _minExecutionOrderFee) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    liquidityService = _liquidityService;
    pyth = _pyth;
    minExecutionOrderFee = _minExecutionOrderFee;

    // Sanity check
    // slither-disable-next-line unused-return
    LiquidityService(_liquidityService).perpStorage();
    IEcoPyth(_pyth).getAssetIds();
  }

  /**
   * Modifiers
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
   * Core Functions
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
  ) external payable nonReentrant onlyAcceptedToken(_tokenIn) returns (uint256 _orderId) {
    uint256 _orderTimestamp = block.timestamp;

    // pre validate
    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);
    if (_executionFee < minExecutionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (_shouldWrap) {
      if (msg.value != _amountIn + _executionFee) revert ILiquidityHandler_InCorrectValueTransfer();
    } else {
      if (msg.value != minExecutionOrderFee) revert ILiquidityHandler_InCorrectValueTransfer();
      IERC20Upgradeable(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
    }

    //1. convert native to WNative (including executionFee)
    _transferInETH();

    _orderId = liquidityOrders.length;

    liquidityOrders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        orderId: _orderId,
        token: _tokenIn,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: true,
        executionFee: _executionFee,
        isNativeOut: _shouldWrap,
        orderTimestamp: _orderTimestamp
      })
    );

    emit LogCreateAddLiquidityOrder(msg.sender, _orderId, _tokenIn, _amountIn, _minOut, _executionFee, _orderTimestamp);
    return _orderId;
  }

  /// @notice Create a new RemoveLiquidity order
  /// @param _tokenOut address token in
  /// @param _amountIn amount token in (based on decimals)
  /// @param _minOut minAmountOut
  /// @param _executionFee The execution fee of order
  /// @param _isNativeOut in case of user need native token
  function createRemoveLiquidityOrder(
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _isNativeOut
  ) external payable nonReentrant onlyAcceptedToken(_tokenOut) returns (uint256 _orderId) {
    uint256 _orderTimestamp = block.timestamp;

    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);
    if (_executionFee < minExecutionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();
    if (msg.value != _executionFee) revert ILiquidityHandler_InCorrectValueTransfer();

    // convert native to WNative (including executionFee)
    _transferInETH();

    IERC20Upgradeable(ConfigStorage(LiquidityService(liquidityService).configStorage()).plp()).safeTransferFrom(
      msg.sender,
      address(this),
      _amountIn
    );

    _orderId = liquidityOrders.length;

    liquidityOrders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        orderId: _orderId,
        token: _tokenOut,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: false,
        executionFee: _executionFee,
        isNativeOut: _isNativeOut,
        orderTimestamp: _orderTimestamp
      })
    );

    emit LogCreateRemoveLiquidityOrder(
      msg.sender,
      _orderId,
      _tokenOut,
      _amountIn,
      _minOut,
      _executionFee,
      _isNativeOut,
      _orderTimestamp
    );
    return _orderId;
  }

  /// @notice Executes liquidity orders within the given range, updating price data and publishing time data as necessary.
  /// @param _endIndex The index of the last liquidity order to execute.
  /// @param _feeReceiver The address to receive the total execution fee for all executed liquidity orders.
  /// @param _priceData Price data from the Pyth oracle.
  /// @param _publishTimeData Publish time data from the Pyth oracle.
  /// @param _minPublishTime Minimum publish time for the Pyth oracle data.
  /// @param _encodedVaas Encoded VaaS data for the Pyth oracle.
  // slither-disable-next-line reentrancy-eth
  function executeOrder(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyOrderExecutor {
    // Get the number of liquidity orders
    uint256 _orderLength = liquidityOrders.length;

    // Ensure there are orders to execute
    if (nextExecutionOrderIndex == _orderLength) revert ILiquidityHandler_NoOrder();

    // Set the end index to the latest order index if it exceeds the number of orders
    uint256 _latestOrderIndex = _orderLength - 1;
    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    // Initialize variables for the execution loop
    LiquidityOrder memory _order;
    uint256 _totalFeeReceiver;
    uint256 _executionFee;

    for (uint256 i = nextExecutionOrderIndex; i <= _endIndex; ) {
      _order = liquidityOrders[i];
      _executionFee = _order.executionFee;
      // Set the flag to indicate that orders are currently being executed
      isExecuting = true;

      try this.executeLiquidity(_order) returns (uint256 actualOut) {
        emit LogExecuteLiquidityOrder(
          _order.account,
          _order.orderId,
          _order.token,
          _order.amount,
          _order.minOut,
          _order.isAdd,
          actualOut
        );
      } catch Error(string memory) {
        //refund in case of revert as message
        _refund(_order);
      } catch (bytes memory) {
        //refund in case of revert as bytes
        _refund(_order);
      }

      isExecuting = false;
      _totalFeeReceiver += _executionFee;

      // clear executed liquidity order
      delete liquidityOrders[i];

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay total collected fees to the executor
    _transferOutETH(_totalFeeReceiver, _feeReceiver);
  }

  /// @notice execute either addLiquidity or removeLiquidity
  /// @param _order LiquidityOrder struct representing the order to execute.
  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256 _amount) {
    // if not in executing state, then revert
    if (!isExecuting) revert ILiquidityHandler_NotExecutionState();

    if (_order.isAdd) {
      IERC20Upgradeable(_order.token).safeTransfer(LiquidityService(liquidityService).vaultStorage(), _order.amount);
      return
        LiquidityService(liquidityService).addLiquidity(_order.account, _order.token, _order.amount, _order.minOut);
    } else {
      uint256 _amountOut = LiquidityService(liquidityService).removeLiquidity(
        _order.account,
        _order.token,
        _order.amount,
        _order.minOut
      );

      if (_order.isNativeOut) {
        _transferOutETH(_amountOut, payable(_order.account));
      } else {
        IERC20Upgradeable(_order.token).safeTransfer(_order.account, _amountOut);
      }
      return _amountOut;
    }
  }

  /// @notice Cancels the specified add/remove liquidity order and refunds the execution fee.
  /// @param _orderIndex Index of the order to cancel.
  function cancelLiquidityOrder(uint256 _orderIndex) external nonReentrant {
    // if order index >= liquidity order's length, then out of bound
    // if order index < next execute index, means order index outdate
    if (_orderIndex >= liquidityOrders.length || _orderIndex < nextExecutionOrderIndex) {
      revert ILiquidityHandler_NoOrder();
    }

    // SLOAD
    LiquidityOrder memory _order = liquidityOrders[_orderIndex];

    // validate if msg.sender is not owned the order, then revert
    if (msg.sender != liquidityOrders[_orderIndex].account) revert ILiquidityHandler_NotOrderOwner();

    delete liquidityOrders[_orderIndex];

    _refund(_order);

    emit LogCancelLiquidityOrder(
      payable(msg.sender),
      _order.orderId,
      _order.token,
      _order.amount,
      _order.minOut,
      _order.isAdd
    );
  }

  /**
   * Private Functions
   */

  /// @notice refund order
  /// @dev this method has not be called directly
  /// @param _order order to execute
  // slither-disable-next-line
  function _refund(LiquidityOrder memory _order) private {
    // if found order with amount 0. means order has been executed or canceled
    if (_order.amount == 0) revert ILiquidityHandler_NoOrder();

    if (_order.isAdd) {
      if (_order.isNativeOut) {
        _transferOutETH(_order.amount, _order.account);
      } else {
        IERC20Upgradeable(_order.token).safeTransfer(_order.account, _order.amount);
      }
      emit LogRefund(_order.account, _order.orderId, _order.token, _order.amount, _order.isNativeOut);
    } else {
      address hlp = ConfigStorage(LiquidityService(liquidityService).configStorage()).plp();
      IERC20Upgradeable(hlp).safeTransfer(_order.account, _order.amount);
      emit LogRefund(_order.account, _order.orderId, hlp, _order.amount, false);
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

  /// @notice get liquidity orders
  function getLiquidityOrders() external view returns (LiquidityOrder[] memory _liquidityOrders) {
    return liquidityOrders;
  }

  /// @notice get liquidity orders length
  function getLiquidityOrderLength() external view returns (uint256) {
    return liquidityOrders.length;
  }

  /**
   * SETTER
   */

  /// @notice setLiquidityService
  /// @param _newLiquidityService liquidityService address
  function setLiquidityService(address _newLiquidityService) external nonReentrant onlyOwner {
    if (_newLiquidityService == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetLiquidityService(liquidityService, _newLiquidityService);
    liquidityService = _newLiquidityService;

    // Sanity check
    LiquidityService(_newLiquidityService).vaultStorage();
  }

  /// @notice setMinExecutionFee
  /// @param _newMinExecutionFee minExecutionFee in ethers
  function setMinExecutionFee(uint256 _newMinExecutionFee) external nonReentrant onlyOwner {
    emit LogSetMinExecutionFee(minExecutionOrderFee, _newMinExecutionFee);
    minExecutionOrderFee = _newMinExecutionFee;
  }

  /// @notice setOrderExecutor
  /// @param _executor address who will be executor
  /// @param _isAllow flag to allow to execute
  function setOrderExecutor(address _executor, bool _isAllow) external nonReentrant onlyOwner {
    orderExecutors[_executor] = _isAllow;

    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  /// @notice Set new Pyth contract address.
  /// @param _pyth New Pyth contract address.
  function setPyth(address _pyth) external nonReentrant onlyOwner {
    if (_pyth == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetPyth(pyth, _pyth);
    pyth = _pyth;

    // Sanity check
    IEcoPyth(_pyth).getAssetIds();
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
