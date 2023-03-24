// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Owned } from "@hmx/base/Owned.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
    uint256 executionFee,
    uint256 orderIndex
  );
  event LogCreateRemoveLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee,
    bool isNativeOut,
    uint256 orderIndex
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
  uint256 public executionOrderFee; // executionOrderFee in tokenAmount unit
  bool isExecuting; // order is executing (prevent direct call executeLiquidity()

  uint256 public nextExecutionOrderIndex;
  LiquidityOrder[] public liquidityOrders; // all liquidityOrder

  mapping(address => bool) public orderExecutors; //address -> flag to execute

  constructor(address _liquidityService, address _pyth, uint256 _executionOrderFee) {
    liquidityService = _liquidityService;
    pyth = _pyth;
    executionOrderFee = _executionOrderFee;
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
  ) external payable nonReentrant onlyAcceptedToken(_tokenIn) returns (uint256 _latestOrderIndex) {
    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);

    //1. convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < executionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (_shouldWrap) {
      if (msg.value != _amountIn + executionOrderFee) {
        revert ILiquidityHandler_InCorrectValueTransfer();
      }
    } else {
      if (msg.value != executionOrderFee) revert ILiquidityHandler_InCorrectValueTransfer();
      IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
    }

    liquidityOrders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenIn,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: true,
        executionFee: _executionFee,
        isNativeOut: _shouldWrap
      })
    );

    _latestOrderIndex = liquidityOrders.length - 1;

    emit LogCreateAddLiquidityOrder(msg.sender, _tokenIn, _amountIn, _minOut, _executionFee, _latestOrderIndex);
    return _latestOrderIndex;
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
  ) external payable nonReentrant onlyAcceptedToken(_tokenOut) returns (uint256 _latestOrderIndex) {
    LiquidityService(liquidityService).validatePreAddRemoveLiquidity(_amountIn);

    //convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < executionOrderFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (msg.value != executionOrderFee) revert ILiquidityHandler_InCorrectValueTransfer();

    IERC20(ConfigStorage(LiquidityService(liquidityService).configStorage()).plp()).safeTransferFrom(
      msg.sender,
      address(this),
      _amountIn
    );

    liquidityOrders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenOut,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: false,
        executionFee: _executionFee,
        isNativeOut: _isNativeOut
      })
    );

    _latestOrderIndex = liquidityOrders.length - 1;

    emit LogCreateRemoveLiquidityOrder(
      msg.sender,
      _tokenOut,
      _amountIn,
      _minOut,
      _executionFee,
      _isNativeOut,
      _latestOrderIndex
    );

    return _latestOrderIndex;
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
    if (
      _orderIndex < nextExecutionOrderIndex || // orderIndex to execute must >= nextExecutionOrderIndex
      liquidityOrders.length <= _orderIndex // orders length must > orderIndex
    ) {
      revert ILiquidityHandler_NoOrder();
    }

    if (_account != liquidityOrders[_orderIndex].account) {
      revert ILiquidityHandler_NotOrderOwner();
    }

    LiquidityOrder memory order = liquidityOrders[_orderIndex];
    delete liquidityOrders[_orderIndex];
    _refund(order);

    emit LogCancelLiquidityOrder(payable(_account), order.token, order.amount, order.minOut, order.isAdd);
  }

  /// @notice refund order
  /// @dev this method has not be called directly
  /// @param _order order to execute
  // slither-disable-next-line
  function _refund(LiquidityOrder memory _order) internal {
    if (_order.amount == 0) {
      revert ILiquidityHandler_NoOrder();
    }
    address _plp = ConfigStorage(LiquidityService(liquidityService).configStorage()).plp();

    if (_order.isAdd) {
      if (_order.isNativeOut) {
        _transferOutETH(_order.amount, _order.account);
      } else {
        IERC20(_order.token).safeTransfer(_order.account, _order.amount);
      }
    } else {
      IERC20(_plp).safeTransfer(_order.account, _order.amount);
    }
  }

  /// @notice orderExecutor pending order
  /// @param _feeReceiver ExecutionFee Receiver Address
  /// @param _priceData Price data from Pyth to be used for updating the market prices
  // slither-disable-next-line reentrancy-eth
  function executeOrder(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes[] memory _priceData
  ) external nonReentrant onlyOrderExecutor {
    uint256 _orderLength = liquidityOrders.length;
    uint256 _latestOrderIndex = _orderLength - 1;
    if (_orderLength == 0 || nextExecutionOrderIndex == _orderLength) {
      revert ILiquidityHandler_NoOrder();
    }

    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    uint256 _updateFee = IPyth(pyth).getUpdateFee(_priceData);
    IWNative(ConfigStorage(LiquidityService(liquidityService).configStorage()).weth()).withdraw(_updateFee);

    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: _updateFee }(_priceData);
    uint256 _totalFeeReceiver = 0;

    for (uint256 i = nextExecutionOrderIndex; i <= _endIndex; ) {
      LiquidityOrder memory _order = liquidityOrders[i];

      delete liquidityOrders[i];

      // refund in case of order updatePythFee > executionFee
      if (_updateFee > _order.executionFee) {
        _refund(_order);
      } else {
        isExecuting = true;

        try this.executeLiquidity(_order) returns (uint256 result) {
          emit LogExecuteLiquidityOrder(
            _order.account,
            _order.token,
            _order.amount,
            _order.minOut,
            _order.isAdd,
            result
          );
        } catch Error(string memory) {
          //refund in case of revert as message
          _refund(_order);
        } catch (bytes memory) {
          //refund in case of revert as bytes
          _refund(_order);
        }
        isExecuting = false;
      }

      _totalFeeReceiver += _order.executionFee;

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay the executor
    _transferOutETH(_totalFeeReceiver - _updateFee, _feeReceiver);
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

        if (_order.isNativeOut) {
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
  function getLiquidityOrders() external view returns (LiquidityOrder[] memory _liquidityOrder) {
    return liquidityOrders;
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
    LiquidityService(_newLiquidityService).vaultStorage();
  }

  /// @notice setMinExecutionFee
  /// @param _newMinExecutionFee minExecutionFee in ethers
  function setMinExecutionFee(uint256 _newMinExecutionFee) external nonReentrant onlyOwner {
    emit LogSetMinExecutionFee(executionOrderFee, _newMinExecutionFee);
    executionOrderFee = _newMinExecutionFee;
  }

  /// @notice setMinExecutionFee
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
    IPyth(_pyth).getValidTimePeriod();
  }
}
