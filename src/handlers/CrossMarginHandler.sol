// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// base
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

// interfaces
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IWNative } from "../interfaces/IWNative.sol";

import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

contract CrossMarginHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, ICrossMarginHandler {
  using SafeERC20Upgradeable for ERC20Upgradeable;

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
  mapping(address => WithdrawOrder[]) public subAccountExecutedWithdrawOrders; // subAccount -> executed orders
  mapping(address => bool) public orderExecutors; //address -> flag to execute

  function initialize(address _crossMarginService, address _pyth, uint256 _executionOrderFee) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    crossMarginService = _crossMarginService;
    pyth = _pyth;
    executionOrderFee = _executionOrderFee;

    // Sanity check
    CrossMarginService(_crossMarginService).vaultStorage();

    // @todo
    // IPyth(_pyth).getValidTimePeriod();
  }

  /**
   * GETTER
   */

  /// @notice get withdraw orders
  function getWithdrawOrders() external view returns (WithdrawOrder[] memory _withdrawOrder) {
    return withdrawOrders;
  }

  function getWithdrawOrderLength() external view returns (uint256) {
    return withdrawOrders.length;
  }

  function getActiveWithdrawOrders(
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrder) {
    // Find the _returnCount
    uint256 _returnCount;
    {
      uint256 _activeOrderCount = withdrawOrders.length - nextExecutionOrderIndex;

      uint256 _afterOffsetCount = _activeOrderCount > _offset ? (_activeOrderCount - _offset) : 0;
      _returnCount = _afterOffsetCount > _limit ? _limit : _afterOffsetCount;

      if (_returnCount == 0) return _withdrawOrder;
    }

    // Initialize order array
    _withdrawOrder = new WithdrawOrder[](_returnCount);

    // Build the array
    {
      for (uint i = 0; i < _returnCount; ) {
        _withdrawOrder[i] = withdrawOrders[nextExecutionOrderIndex + _offset + i];
        unchecked {
          ++i;
        }
      }

      return _withdrawOrder;
    }
  }

  function getExecutedWithdrawOrders(
    address _subAccount,
    uint256 _limit,
    uint256 _offset
  ) external view returns (WithdrawOrder[] memory _withdrawOrder) {
    // Find the _returnCount and
    uint256 _returnCount;
    {
      uint256 _exeuctedOrderCount = subAccountExecutedWithdrawOrders[_subAccount].length;
      uint256 _afterOffsetCount = _exeuctedOrderCount > _offset ? (_exeuctedOrderCount - _offset) : 0;
      _returnCount = _afterOffsetCount > _limit ? _limit : _afterOffsetCount;

      if (_returnCount == 0) return _withdrawOrder;
    }

    // Initialize order array
    _withdrawOrder = new WithdrawOrder[](_returnCount);

    // Build the array
    {
      for (uint i = 0; i < _returnCount; ) {
        _withdrawOrder[i] = subAccountExecutedWithdrawOrders[_subAccount][_offset + i];
        unchecked {
          ++i;
        }
      }
      return _withdrawOrder;
    }
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
      ERC20Upgradeable(_token).safeTransfer(_crossMarginService.vaultStorage(), _amount);
    } else {
      // Transfer depositing token from trader's wallet to VaultStorage
      ERC20Upgradeable(_token).safeTransferFrom(msg.sender, _crossMarginService.vaultStorage(), _amount);
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
        crossMarginService: CrossMarginService(crossMarginService),
        createdTimestamp: uint48(block.timestamp),
        executedTimestamp: 0,
        status: 0 // pending
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
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyOrderExecutor {
    uint256 _orderLength = withdrawOrders.length;

    if (nextExecutionOrderIndex == _orderLength) revert ICrossMarginHandler_NoOrder();

    uint256 _latestOrderIndex = _orderLength - 1;

    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

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

        // update order status
        _order.status = 1; // success
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

        // update order status
        _order.status = 2; // fail
      }

      // assign exec time
      _order.executedTimestamp = uint48(block.timestamp);

      isExecuting = false;
      _totalFeeReceiver += _executionFee;

      // save to executed order first
      subAccountExecutedWithdrawOrders[_getSubAccount(_order.account, _order.subAccountId)].push(_order);
      // clear executed withdraw order
      delete withdrawOrders[i];

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay the executor
    _transferOutETH(_totalFeeReceiver, _feeReceiver);
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
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable nonReentrant onlyOwner {
    // Call update oracle price
    // slither-disable-next-line arbitrary-send-eth
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

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
    // @todo
    // IPyth(_pyth).getValidTimePeriod();
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

  /// @notice convert collateral
  function convertSGlpCollateral(
    uint8 _subAccountId,
    address _tokenOut,
    uint256 _amountIn
  ) external nonReentrant onlyAcceptedToken(_tokenOut) returns (uint256 _amountOut) {
    return
      CrossMarginService(crossMarginService).convertSGlpCollateral(msg.sender, _subAccountId, _tokenOut, _amountIn);
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

  function _getSubAccount(address _primary, uint8 _subAccountId) private pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  receive() external payable {
    // @dev Cannot enable this check due to Solidity Fallback Function Gas Limit introduced in 0.8.17.
    // ref - https://stackoverflow.com/questions/74930609/solidity-fallback-function-gas-limit
    // require(msg.sender == ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth());
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
