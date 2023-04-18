// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "@hmx/base/Owned.sol";

// interfaces
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IWNative } from "../interfaces/IWNative.sol";

import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract CrossMarginHandler is Owned, ReentrancyGuard, ICrossMarginHandler {
  using SafeERC20 for ERC20;

  /**
   * Events
   */
  event LogDepositCollateral(
    address indexed primaryAccount,
    uint256 indexed subAccountId,
    address token,
    uint256 amount
  );
  event LogWithdrawCollateral(
    address indexed primaryAccount,
    uint256 indexed subAccountId,
    address token,
    uint256 amount
  );
  event LogSetCrossMarginService(address indexed oldCrossMarginService, address newCrossMarginService);
  event LogSetPyth(address indexed oldPyth, address newPyth);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogCreateWithdrawOrder(
    address indexed account,
    uint8 indexed subAccountId,
    uint256 indexed orderId,
    address token,
    uint256 amount,
    uint256 executionFee,
    bool shouldUnwrap
  );
  event LogCancelWithdrawOrder(
    address indexed account,
    uint8 indexed subAccountId,
    uint256 indexed orderId,
    address token,
    uint256 amount,
    uint256 executionFee,
    bool shouldUnwrap
  );
  event LogExecuteWithdrawOrder(
    address indexed account,
    uint8 indexed subAccountId,
    uint256 indexed orderId,
    address token,
    uint256 amount,
    bool shouldUnwrap,
    bool isSuccess
  );

  /**
   * Constants
   */
  uint64 internal constant RATE_PRECISION = 1e18;

  /**
   * States
   */
  address public crossMarginService;
  address public pyth;

  uint256 public nextExecutionOrderIndex;
  uint256 public executionOrderFee; // executionOrderFee in tokenAmount unit
  bool private isExecuting; // order is executing (prevent direct call executeWithdrawOrder()

  WithdrawOrder[] public withdrawOrders; // all withdrawOrder
  mapping(address => bool) public orderExecutors; //address -> flag to execute

  constructor(address _crossMarginService, address _pyth, uint256 _executionOrderFee) {
    crossMarginService = _crossMarginService;
    pyth = _pyth;
    executionOrderFee = _executionOrderFee;

    // Sanity check
    CrossMarginService(_crossMarginService).vaultStorage();
    IPyth(_pyth).getUpdateFee(new bytes[](0));
  }

  /**
   * GETTER
   */

  /// @notice get withdraw orders
  function getWithdrawOrders() external view returns (WithdrawOrder[] memory _withdrawOrder) {
    return withdrawOrders;
  }

  /**
   * Modifiers
   */

  // NOTE: Validate only accepted collateral token to be deposited
  modifier onlyAcceptedToken(address _token) {
    ConfigStorage(CrossMarginService(crossMarginService).configStorage()).validateAcceptedCollateral(_token);
    _;
  }

  modifier onlyOrderExecutor() {
    if (!orderExecutors[msg.sender]) revert ICrossMarginHandler_NotWhitelisted();
    _;
  }

  /**
   * CALCULATION
   */

  /// @notice Calculate new trader balance after deposit collateral token.
  /// @dev This uses to call deposit function on service and calculate new trader balance when they depositing token as collateral.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's deposited as collateral.
  /// @param _amount Token depositing amount.
  function depositCollateral(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    bool _shouldWrap
  ) external payable nonReentrant onlyAcceptedToken(_token) {
    CrossMarginService _crossMarginService = CrossMarginService(crossMarginService);

    if (_shouldWrap) {
      // Prevent mismatch msgValue and the input amount
      if (msg.value != _amount) {
        revert ICrossMarginHandler_MismatchMsgValue();
      }

      // Wrap the native to wNative. The _token must be wNative.
      // If not, it would revert transfer amount exceed on the next line.
      // slither-disable-next-line arbitrary-send-eth
      IWNative(_token).deposit{ value: _amount }();
      // Transfer those wNative token from this contract to VaultStorage
      ERC20(_token).safeTransfer(_crossMarginService.vaultStorage(), _amount);
    } else {
      // Transfer depositing token from trader's wallet to VaultStorage
      ERC20(_token).safeTransferFrom(msg.sender, _crossMarginService.vaultStorage(), _amount);
    }

    // Call service to deposit collateral
    _crossMarginService.depositCollateral(msg.sender, _subAccountId, _token, _amount);

    emit LogDepositCollateral(msg.sender, _subAccountId, _token, _amount);
  }

  /// @notice Calculate new trader balance after withdraw collateral token.
  /// @dev This uses to call withdraw function on service and calculate new trader balance when they withdrawing token as collateral.
  /// @param _subAccountId Trader's sub account ID.
  /// @param _token Token that's withdrawn as collateral.
  /// @param _amount Token withdrawing amount.
  /// @param _executionFee The execution fee of order.
  function createWithdrawCollateralOrder(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable nonReentrant onlyAcceptedToken(_token) returns (uint256 _orderId) {
    if (_executionFee < executionOrderFee) revert ICrossMarginHandler_InsufficientExecutionFee();
    if (msg.value != executionOrderFee) revert ICrossMarginHandler_InCorrectValueTransfer();

    // convert native to WNative (including executionFee)
    _transferInETH();

    _orderId = withdrawOrders.length;

    withdrawOrders.push(
      WithdrawOrder({
        account: payable(msg.sender),
        orderId: _orderId,
        token: _token,
        amount: _amount,
        executionFee: _executionFee,
        shouldUnwrap: _shouldUnwrap,
        subAccountId: _subAccountId,
        crossMarginService: CrossMarginService(crossMarginService)
      })
    );

    emit LogCreateWithdrawOrder(msg.sender, _subAccountId, _orderId, _token, _amount, _executionFee, _shouldUnwrap);
    return _orderId;
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
    // SLOAD
    CrossMarginService _crossMarginService = CrossMarginService(crossMarginService);

    uint256 _orderLength = withdrawOrders.length;

    if (nextExecutionOrderIndex == _orderLength) revert ICrossMarginHandler_NoOrder();

    uint256 _latestOrderIndex = _orderLength - 1;

    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    // Call update oracle price
    uint256 _updateFee = IPyth(pyth).getUpdateFee(_priceData);
    IWNative(ConfigStorage(_crossMarginService.configStorage()).weth()).withdraw(_updateFee);

    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: _updateFee }(_priceData);

    WithdrawOrder memory _order;
    uint256 _totalFeeReceiver;
    uint256 _executionFee;

    for (uint256 i = nextExecutionOrderIndex; i <= _endIndex; ) {
      _order = withdrawOrders[i];
      _executionFee = _order.executionFee;

      isExecuting = true;

      try this.executeWithdrawOrder(_order) {
        emit LogExecuteWithdrawOrder(
          _order.account,
          _order.subAccountId,
          _order.orderId,
          _order.token,
          _order.amount,
          _order.shouldUnwrap,
          true
        );
      } catch Error(string memory) {
        // Do nothing
      } catch (bytes memory) {
        emit LogExecuteWithdrawOrder(
          _order.account,
          _order.subAccountId,
          _order.orderId,
          _order.token,
          _order.amount,
          _order.shouldUnwrap,
          false
        );
      }

      isExecuting = false;
      _totalFeeReceiver += _executionFee;

      // clear executed withdraw order
      delete withdrawOrders[i];

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay the executor
    _transferOutETH(_totalFeeReceiver - _updateFee, _feeReceiver);
  }

  function executeWithdrawOrder(WithdrawOrder memory _order) external {
    // if not in executing state, then revert
    if (!isExecuting) revert ICrossMarginHandler_NotExecutionState();

    // Call service to withdraw collateral
    if (_order.shouldUnwrap) {
      // Withdraw wNative straight to this contract first.
      _order.crossMarginService.withdrawCollateral(
        _order.account,
        _order.subAccountId,
        _order.token,
        _order.amount,
        address(this)
      );
      // Then we unwrap the wNative token. The receiving amount should be the exact same as _amount. (No fee deducted when withdraw)
      IWNative(_order.token).withdraw(_order.amount);

      // slither-disable-next-line arbitrary-send-eth
      payable(_order.account).transfer(_order.amount);
    } else {
      // Withdraw _token straight to the user
      _order.crossMarginService.withdrawCollateral(
        _order.account,
        _order.subAccountId,
        _order.token,
        _order.amount,
        _order.account
      );
    }

    emit LogWithdrawCollateral(_order.account, _order.subAccountId, _order.token, _order.amount);
  }

  /// @notice Cancel order
  /// @param _orderIndex orderIndex of user order
  function cancelWithdrawOrder(uint256 _orderIndex) external nonReentrant {
    address _account = msg.sender;

    // if order index >= liquidity order's length, then out of bound
    // if order index < next execute index, means order index outdate
    if (_orderIndex >= withdrawOrders.length || _orderIndex < nextExecutionOrderIndex) {
      revert ICrossMarginHandler_NoOrder();
    }

    // _account is not owned this order
    if (_account != withdrawOrders[_orderIndex].account) revert ICrossMarginHandler_NotOrderOwner();

    // load _order
    WithdrawOrder memory _order = withdrawOrders[_orderIndex];
    delete withdrawOrders[_orderIndex];

    emit LogCreateWithdrawOrder(
      payable(_account),
      _order.subAccountId,
      _order.orderId,
      _order.token,
      _order.amount,
      _order.executionFee,
      _order.shouldUnwrap
    );
  }

  /// @notice Check funding fee surplus and transfer to PLP
  /// @dev Check if value on funding fee reserve have exceed balance for paying to traders
  ///      - If yes means exceed value are the surplus for platform and can be booked to PLP
  function withdrawFundingFeeSurplus(
    address _stableToken,
    bytes[] memory _priceData
  ) external payable nonReentrant onlyOwner {
    if (msg.value != IPyth(pyth).getUpdateFee(_priceData)) revert ICrossMarginHandler_InCorrectValueTransfer();

    // Call update oracle price
    // slither-disable-next-line arbitrary-send-eth
    IPyth(pyth).updatePriceFeeds{ value: msg.value }(_priceData);

    CrossMarginService(crossMarginService).withdrawFundingFeeSurplus(_stableToken);
  }

  /**
   * Setters
   */

  /// @notice Set new CrossMarginService contract address.
  /// @param _crossMarginService New CrossMarginService contract address.
  function setCrossMarginService(address _crossMarginService) external nonReentrant onlyOwner {
    if (_crossMarginService == address(0)) revert ICrossMarginHandler_InvalidAddress();
    emit LogSetCrossMarginService(crossMarginService, _crossMarginService);
    crossMarginService = _crossMarginService;

    // Sanity check
    CrossMarginService(_crossMarginService).vaultStorage();
  }

  /// @notice Set new Pyth contract address.
  /// @param _pyth New Pyth contract address.
  function setPyth(address _pyth) external nonReentrant onlyOwner {
    if (_pyth == address(0)) revert ICrossMarginHandler_InvalidAddress();
    emit LogSetPyth(pyth, _pyth);
    pyth = _pyth;

    // Sanity check
    IPyth(_pyth).getValidTimePeriod();
  }

  /// @notice setMinExecutionFee
  /// @param _newMinExecutionFee minExecutionFee in ethers
  function setMinExecutionFee(uint256 _newMinExecutionFee) external nonReentrant onlyOwner {
    emit LogSetMinExecutionFee(executionOrderFee, _newMinExecutionFee);

    executionOrderFee = _newMinExecutionFee;
  }

  /// @notice setOrderExecutor
  /// @param _executor address who will be executor
  /// @param _isAllow flag to allow to execute
  function setOrderExecutor(address _executor, bool _isAllow) external nonReentrant onlyOwner {
    orderExecutors[_executor] = _isAllow;

    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  /**
   * Private Functions
   */

  /// @notice Transfer in ETH from user to be used as execution fee
  /// @dev The received ETH will be wrapped into WETH and store in this contract for later use.
  function _transferInETH() private {
    IWNative(ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth()).deposit{
      value: msg.value
    }();
  }

  /// @notice Transfer out ETH to the receiver
  /// @dev The stored WETH will be unwrapped and transfer as native token
  /// @param _amountOut Amount of ETH to be transferred
  /// @param _receiver The receiver of ETH in its native form. The receiver must be able to accept native token.
  function _transferOutETH(uint256 _amountOut, address _receiver) private {
    IWNative(ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth()).withdraw(_amountOut);
    // slither-disable-next-line arbitrary-send-eth
    payable(_receiver).transfer(_amountOut);
  }

  receive() external payable {
    // @dev Cannot enable this check due to Solidity Fallback Function Gas Limit introduced in 0.8.17.
    // ref - https://stackoverflow.com/questions/74930609/solidity-fallback-function-gas-limit
    // require(msg.sender == ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth());
  }
}
