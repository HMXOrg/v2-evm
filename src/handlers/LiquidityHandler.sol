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
  event LogMaxExecutionChuck(uint256 oldValue, uint256 newValue);
  event LogSetPyth(address oldPyth, address newPyth);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event LogCreateAddLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed tokenIn,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    uint48 createdTimestamp
  );
  event LogCreateRemoveLiquidityOrder(
    address indexed account,
    uint256 indexed orderId,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    bool isNativeOut,
    uint48 createdTimestamp
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
  uint256 public maxExecutionChuck; // maximum execution order sizes per request

  LiquidityOrder[] public liquidityOrders; // all liquidityOrder
  mapping(address => bool) public orderExecutors; // address -> whitelist executors
  mapping(address => LiquidityOrder[]) public accountExecutedLiquidityOrders; // account -> executed orders

  /// @notice Initializes the LiquidityHandler contract with the provided configuration parameters.
  /// @param _liquidityService Address of the LiquidityService contract.
  /// @param _pyth Address of the Pyth contract.
  /// @param _minExecutionOrderFee Minimum execution fee for execute order.
  function initialize(
    address _liquidityService,
    address _pyth,
    uint256 _minExecutionOrderFee,
    uint256 _maxExecutionChuck
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    liquidityService = _liquidityService;
    pyth = _pyth;
    minExecutionOrderFee = _minExecutionOrderFee;
    maxExecutionChuck = _maxExecutionChuck;

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
  /// @param _minOut minHLP out
  /// @param _executionFee The execution fee of order
  /// @param _shouldWrap in case of sending native token
  function createAddLiquidityOrder(
    address _tokenIn,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap
  ) external payable nonReentrant onlyAcceptedToken(_tokenIn) returns (uint256 _orderId) {
    // pre validate
    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);
    if (_executionFee < minExecutionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();
    if (_shouldWrap && _tokenIn != ConfigStorage(LiquidityService(liquidityService).configStorage()).weth())
      revert ILiquidityHandler_NotWNativeToken();

    if (_shouldWrap) {
      if (msg.value != _amountIn + _executionFee) revert ILiquidityHandler_InCorrectValueTransfer();
    } else {
      if (msg.value != _executionFee) revert ILiquidityHandler_InCorrectValueTransfer();
      IERC20Upgradeable(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
    }

    // convert native to WNative (including executionFee)
    _transferInETH();

    _orderId = liquidityOrders.length;

    liquidityOrders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        orderId: _orderId,
        token: _tokenIn,
        amount: _amountIn,
        minOut: _minOut,
        actualAmountOut: 0,
        isAdd: true,
        executionFee: _executionFee,
        isNativeOut: _shouldWrap,
        createdTimestamp: uint48(block.timestamp),
        executedTimestamp: 0,
        status: LiquidityOrderStatus.PENDING
      })
    );

    emit LogCreateAddLiquidityOrder(
      msg.sender,
      _orderId,
      _tokenIn,
      _amountIn,
      _minOut,
      _executionFee,
      uint48(block.timestamp)
    );
    return _orderId;
  }

  /// @notice Create a new RemoveLiquidity order
  /// @param _tokenOut The address of the token user wish to receive
  /// @param _amountIn The amount of HLP to remove liquidity
  /// @param _minOut minAmountOut of the selected token out
  /// @param _executionFee The execution fee of order
  /// @param _isNativeOut If true, the contract will try to unwrap it into Native Token
  function createRemoveLiquidityOrder(
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _isNativeOut
  ) external payable nonReentrant onlyAcceptedToken(_tokenOut) returns (uint256 _orderId) {
    // pre validate
    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);
    if (_executionFee < minExecutionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();
    if (msg.value != _executionFee) revert ILiquidityHandler_InCorrectValueTransfer();
    if (_isNativeOut && _tokenOut != ConfigStorage(LiquidityService(liquidityService).configStorage()).weth())
      revert ILiquidityHandler_NotWNativeToken();

    // convert native to WNative (including executionFee)
    _transferInETH();

    // transfers ERC-20 token from user's account to this contract
    IERC20Upgradeable(ConfigStorage(LiquidityService(liquidityService).configStorage()).hlp()).safeTransferFrom(
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
        actualAmountOut: 0,
        isAdd: false,
        executionFee: _executionFee,
        isNativeOut: _isNativeOut,
        createdTimestamp: uint48(block.timestamp),
        executedTimestamp: 0,
        status: LiquidityOrderStatus.PENDING
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
      uint48(block.timestamp)
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
    bytes32[] calldata _priceData,
    bytes32[] calldata _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyOrderExecutor {
    uint256 _nextExecutionOrderIndex = nextExecutionOrderIndex;

    // Get the number of liquidity orders
    uint256 _orderLength = liquidityOrders.length;

    // Ensure there are orders to execute
    if (_nextExecutionOrderIndex == _orderLength) revert ILiquidityHandler_NoOrder();

    // Set the end index to the latest order index if it exceeds the number of orders
    uint256 _latestOrderIndex = _orderLength - 1;
    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    // split execution into chunk for preventing exceed block gas limit
    if (_endIndex - _nextExecutionOrderIndex > maxExecutionChuck)
      _endIndex = _nextExecutionOrderIndex + maxExecutionChuck;

    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    // Initialize variables for the execution loop
    LiquidityOrder memory _order;
    uint256 _totalFeeReceiver;
    uint256 _executionFee;

    for (uint256 i = _nextExecutionOrderIndex; i <= _endIndex; ) {
      _order = liquidityOrders[i];
      if (_order.amount > 0) {
        _executionFee = _order.executionFee;

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

          // update order status
          _order.status = LiquidityOrderStatus.SUCCESS;
          _order.actualAmountOut = actualOut;
        } catch Error(string memory errMsg) {
          _handleOrderFail(_order, errMsg);
        } catch Panic(uint /*errorCode*/) {
          _handleOrderFail(_order, "Panic occurred while executing the withdraw order");
        } catch (bytes memory errMsg) {
          _handleOrderFail(_order, string(errMsg));
        }

        // assign exec time
        _order.executedTimestamp = uint48(block.timestamp);
        _totalFeeReceiver += _executionFee;

        // save to executed order first
        accountExecutedLiquidityOrders[_order.account].push(_order);
        // clear executed liquidity order
        delete liquidityOrders[i];
      }

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay total collected fees to the executor
    _transferOutETH(_totalFeeReceiver, _feeReceiver);
  }

  function _handleOrderFail(LiquidityOrder memory order, string memory /* errMsg */) internal {
    //refund in case of revert as order
    _refund(order);
    order.status = LiquidityOrderStatus.FAIL;
  }

  /// @notice execute either addLiquidity or removeLiquidity
  /// @param _order LiquidityOrder struct representing the order to execute.
  function executeLiquidity(LiquidityOrder calldata _order) external returns (uint256 _amountOut) {
    // if not in executing state, then revert
    if (msg.sender != address(this)) revert ILiquidityHandler_Unauthorized();

    if (_order.isAdd) {
      IERC20Upgradeable(_order.token).safeTransfer(LiquidityService(liquidityService).vaultStorage(), _order.amount);
      _amountOut = LiquidityService(liquidityService).addLiquidity(
        _order.account,
        _order.token,
        _order.amount,
        _order.minOut
      );

      return _amountOut;
    } else {
      _amountOut = LiquidityService(liquidityService).removeLiquidity(
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
    uint256 _amount = _order.amount;
    if (_amount == 0) return;

    address _account = _order.account;

    // Add Liquidity order
    if (_order.isAdd) {
      if (_order.isNativeOut) {
        _transferOutETH(_amount, _account);
      } else {
        IERC20Upgradeable(_order.token).safeTransfer(_account, _amount);
      }
      emit LogRefund(_account, _order.orderId, _order.token, _amount, _order.isNativeOut);
    }
    // Remove Liquidity order
    else {
      address hlp = ConfigStorage(LiquidityService(liquidityService).configStorage()).hlp();
      IERC20Upgradeable(hlp).safeTransfer(_account, _amount);
      emit LogRefund(_account, _order.orderId, hlp, _amount, false);
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
    // To mitigate potential attacks, the call method is utilized,
    // allowing the contract to bypass any revert calls from the destination address.
    // By setting the gas limit to 2300, equivalent to the gas limit of the transfer method,
    // the transaction maintains a secure execution."
    (bool success, ) = _receiver.call{ value: _amountOut, gas: 2300 }("");
    // shhh compiler
    success;
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

  function getActiveLiquidityOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _liquidityOrders) {
    // Find the _returnCount
    uint256 _returnCount;
    {
      uint256 _activeOrderCount = liquidityOrders.length - nextExecutionOrderIndex;

      uint256 _afterOffsetCount = _activeOrderCount > _offset ? (_activeOrderCount - _offset) : 0;
      _returnCount = _afterOffsetCount > _limit ? _limit : _afterOffsetCount;

      if (_returnCount == 0) return _liquidityOrders;
    }

    // Initialize order array
    _liquidityOrders = new LiquidityOrder[](_returnCount);

    // Build the array
    {
      for (uint i = 0; i < _returnCount; ) {
        _liquidityOrders[i] = liquidityOrders[nextExecutionOrderIndex + _offset + i];
        unchecked {
          ++i;
        }
      }

      return _liquidityOrders;
    }
  }

  function getExecutedLiquidityOrders(
    address _account,
    uint256 _limit,
    uint256 _offset
  ) external view returns (LiquidityOrder[] memory _liquidityOrders) {
    // Find the _returnCount and
    uint256 _returnCount;
    {
      uint256 _exeuctedOrderCount = accountExecutedLiquidityOrders[_account].length;
      uint256 _afterOffsetCount = _exeuctedOrderCount > _offset ? (_exeuctedOrderCount - _offset) : 0;
      _returnCount = _afterOffsetCount > _limit ? _limit : _afterOffsetCount;

      if (_returnCount == 0) return _liquidityOrders;
    }

    // Initialize order array
    _liquidityOrders = new LiquidityOrder[](_returnCount);

    // Build the array
    {
      for (uint i = 0; i < _returnCount; ) {
        _liquidityOrders[i] = accountExecutedLiquidityOrders[_account][_offset + i];
        unchecked {
          ++i;
        }
      }
      return _liquidityOrders;
    }
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

  /// @notice setMaxExecutionChuck
  /// @param _maxExecutionChuck maximum check sizes when execute orders
  function setMaxExecutionChuck(uint256 _maxExecutionChuck) external nonReentrant onlyOwner {
    emit LogMaxExecutionChuck(maxExecutionChuck, _maxExecutionChuck);
    maxExecutionChuck = _maxExecutionChuck;
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
