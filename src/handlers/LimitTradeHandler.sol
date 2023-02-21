// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "../base/Owned.sol";

// Interfaces
import { ILimitTradeHandler } from "./interfaces/ILimitTradeHandler.sol";
import { IWNative } from "../interfaces/IWNative.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";

contract LimitTradeHandler is Owned, ReentrancyGuard, ILimitTradeHandler {
  // CONSTANTS
  uint8 internal constant BUY = 0;
  uint8 internal constant SELL = 1;

  // EVENTS
  event LogSetTradeService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event LogSetPyth(address oldValue, address newValue);
  event CreateLimitOrder(
    address indexed account,
    uint256 indexed subAccountId,
    uint256 orderIndex,
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    bool triggerAboveThreshold,
    uint256 executionFee,
    bool reduceOnly
  );
  event ExecuteLimitOrder(
    address indexed account,
    uint256 indexed subAccountId,
    uint256 orderIndex,
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    bool triggerAboveThreshold,
    uint256 executionFee,
    uint256 executionPrice,
    bool reduceOnly
  );
  event UpdateLimitOrder(
    address indexed account,
    uint256 indexed subAccountId,
    uint256 orderIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    bool triggerAboveThreshold,
    bool reduceOnly
  );
  event CancelLimitOrder(
    address indexed account,
    uint256 indexed subAccountId,
    uint256 orderIndex,
    uint256 marketIndex,
    int256 sizeDelta,
    uint256 triggerPrice,
    bool triggerAboveThreshold,
    uint256 executionFee,
    bool reduceOnly
  );

  // STATES
  address public weth;
  address public tradeService;
  address public pyth;
  uint256 public minExecutionFee; // Minimum execution fee to be collected by the order executor addresses for gas
  bool public isAllowAllExecutor; // If this is true, everyone can execute limit orders
  mapping(address => bool) public orderExecutors; // The allowed addresses to execute limit orders
  mapping(address => mapping(uint256 => LimitOrder)) public limitOrders; // Array of Limit Orders of each sub-account
  mapping(address => uint256) public limitOrdersIndex; // The last limit order index of each sub-account

  constructor(address _weth, address _tradeService, address _pyth, uint256 _minExecutionFee) {
    // @todo - Sanity check
    weth = _weth;
    tradeService = _tradeService;
    pyth = _pyth;
    minExecutionFee = _minExecutionFee;
  }

  receive() external payable {
    if (msg.sender != weth) revert ILimitTradeHandler_InvalidSender();
  }

  /**
   * Modifiers
   */

  // Only whitelisted addresses can be able to execute limit orders
  modifier onlyOrderExecutor() {
    if (!isAllowAllExecutor && !orderExecutors[msg.sender]) revert ILimitTradeHandler_NotWhitelisted();
    _;
  }

  /**
   * Setters
   */
  function setTradeService(address _newTradeService) external onlyOwner {
    // @todo - Sanity check
    if (_newTradeService == address(0)) revert ILimitTradeHandler_InvalidAddress();
    emit LogSetTradeService(address(tradeService), _newTradeService);
    tradeService = _newTradeService;
  }

  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  function setOrderExecutor(address _executor, bool _isAllow) external onlyOwner {
    orderExecutors[_executor] = _isAllow;
    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  function setPyth(address _newPyth) external onlyOwner {
    // @todo - Sanity check
    if (_newPyth == address(0)) revert ILimitTradeHandler_InvalidAddress();
    emit LogSetPyth(address(tradeService), _newPyth);
    pyth = _newPyth;
  }

  /**
   * Core Functions
   */
  /// @notice Create a new limit order
  /// @param _subAccountId Sub-account Id
  /// @param _marketIndex Market Index
  /// @param _sizeDelta How much the position size will change in USD (1e30), can be negative for INCREASE order
  /// @param _triggerPrice The price that this limit order will be triggered
  /// @param _triggerAboveThreshold The current price must go above/below the trigger price for the order to be executed
  /// @param _executionFee The execution fee of this limit order
  /// @param _reduceOnly If true, it's a Reduce-Only order which will not flip the side of the position
  function createOrder(
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee,
    bool _reduceOnly
  ) external payable nonReentrant {
    // Transfer in the native token to be used as execution fee
    _transferInETH();

    // Check if exectuion fee is lower than minExecutionFee, then it's too low. We won't allow it.
    if (_executionFee < minExecutionFee) revert ILimitTradeHandler_InsufficientExecutionFee();
    // The attached native token must be equal to _executionFee
    if (msg.value != _executionFee) revert ILimitTradeHandler_IncorrectValueTransfer();

    address _subAccount = _getSubAccount(msg.sender, _subAccountId);
    uint256 _orderIndex = limitOrdersIndex[_subAccount];
    LimitOrder memory _order = LimitOrder({
      account: msg.sender,
      subAccountId: _subAccountId,
      marketIndex: _marketIndex,
      sizeDelta: _sizeDelta,
      triggerPrice: _triggerPrice,
      triggerAboveThreshold: _triggerAboveThreshold,
      executionFee: _executionFee,
      reduceOnly: _reduceOnly
    });

    // Insert the limit order into the list
    limitOrdersIndex[_subAccount] = _orderIndex + 1;
    limitOrders[_subAccount][_orderIndex] = _order;

    emit CreateLimitOrder(
      msg.sender,
      _subAccountId,
      _orderIndex,
      _marketIndex,
      _sizeDelta,
      _triggerPrice,
      _triggerAboveThreshold,
      _executionFee,
      _reduceOnly
    );
  }

  /// @notice Execute a limit order
  /// @param _account the primary account of the order
  /// @param _subAccountId Sub-account Id
  /// @param _orderIndex Order Index which could be retrieved from the emitted event from `createOrder()`
  /// @param _feeReceiver Which address will receive the execution fee for this transaction
  /// @param _priceData Price data from Pyth to be used for updating the market prices
  function executeOrder(
    address _account,
    uint256 _subAccountId,
    uint256 _orderIndex,
    address payable _feeReceiver,
    bytes[] memory _priceData
  ) external nonReentrant onlyOrderExecutor {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    LimitOrder memory _order = limitOrders[_subAccount][_orderIndex];
    // Check if this order still exists
    if (_order.account == address(0)) revert ILimitTradeHandler_NonExistentOrder();

    // Update price to Pyth
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    // Validate if the current price is valid for the execution of this order
    (uint256 _currentPrice, ) = validatePositionOrderPrice(
      _order.triggerAboveThreshold,
      _order.triggerPrice,
      _order.marketIndex,
      _order.sizeDelta > 0,
      true
    );

    // Retrieve existing position
    bytes32 _positionId = _getPositionId(_subAccount, _order.marketIndex);
    IPerpStorage.Position memory _existingPosition = IPerpStorage(ITradeService(tradeService).perpStorage())
      .getPositionById(_positionId);
    bool _positionIsLong = _existingPosition.positionSizeE30 > 0;
    bool _isNewPosition = _existingPosition.positionSizeE30 == 0;

    // Execute the order
    if (_order.sizeDelta > 0) {
      // BUY
      if (_isNewPosition || _positionIsLong) {
        // New position and Long position
        // just increase position when BUY
        ITradeService(tradeService).increasePosition({
          _primaryAccount: _account,
          _subAccountId: _subAccountId,
          _marketIndex: _order.marketIndex,
          _sizeDelta: _order.sizeDelta
        });
      } else if (!_positionIsLong) {
        bool _flipSide = !_order.reduceOnly && _order.sizeDelta > (-_existingPosition.positionSizeE30);
        if (_flipSide) {
          // Flip the position
          // Fully close Short position
          ITradeService(tradeService).decreasePosition({
            _account: _account,
            _subAccountId: _subAccountId,
            _marketIndex: _order.marketIndex,
            _positionSizeE30ToDecrease: uint256(-_existingPosition.positionSizeE30)
          });
          // Flip it to Long position
          ITradeService(tradeService).increasePosition({
            _primaryAccount: _account,
            _subAccountId: _subAccountId,
            _marketIndex: _order.marketIndex,
            _sizeDelta: _order.sizeDelta + _existingPosition.positionSizeE30
          });
        } else {
          // Not flip
          ITradeService(tradeService).decreasePosition({
            _account: _account,
            _subAccountId: _subAccountId,
            _marketIndex: _order.marketIndex,
            _positionSizeE30ToDecrease: _min(uint256(_order.sizeDelta), uint256(-_existingPosition.positionSizeE30))
          });
        }
      }
    } else if (_order.sizeDelta < 0) {
      // SELL
      if (_isNewPosition || !_positionIsLong) {
        // New position and Short position
        // just increase position when SELL
        ITradeService(tradeService).increasePosition({
          _primaryAccount: _account,
          _subAccountId: _subAccountId,
          _marketIndex: _order.marketIndex,
          _sizeDelta: _order.sizeDelta
        });
      }
    } else if (_positionIsLong) {
      bool _flipSide = !_order.reduceOnly && (-_order.sizeDelta) > _existingPosition.positionSizeE30;
      if (_flipSide) {
        // Flip the position
        // Fully close Long position
        ITradeService(tradeService).decreasePosition({
          _account: _account,
          _subAccountId: _subAccountId,
          _marketIndex: _order.marketIndex,
          _positionSizeE30ToDecrease: uint256(-_existingPosition.positionSizeE30)
        });
        // Flip it to Short position
        ITradeService(tradeService).increasePosition({
          _primaryAccount: _account,
          _subAccountId: _subAccountId,
          _marketIndex: _order.marketIndex,
          _sizeDelta: _order.sizeDelta + _existingPosition.positionSizeE30
        });
      } else {
        // Not flip
        ITradeService(tradeService).decreasePosition({
          _account: _account,
          _subAccountId: _subAccountId,
          _marketIndex: _order.marketIndex,
          _positionSizeE30ToDecrease: _min(uint256(-_order.sizeDelta), uint256(_existingPosition.positionSizeE30))
        });
      }
    }

    // Delete this executed order from the list
    delete limitOrders[_subAccount][_orderIndex];

    // Pay the executor
    _transferOutETH(_order.executionFee, _feeReceiver);

    emit ExecuteLimitOrder(
      _account,
      _subAccountId,
      _orderIndex,
      _order.marketIndex,
      _order.sizeDelta,
      _order.triggerPrice,
      _order.triggerAboveThreshold,
      _order.executionFee,
      _currentPrice,
      _order.reduceOnly
    );
  }

  /// @notice Cancel a limit order
  /// @param _subAccountId Sub-account Id
  /// @param _orderIndex Order Index which could be retrieved from the emitted event from `createOrder()`
  function cancelOrder(uint256 _subAccountId, uint256 _orderIndex) external nonReentrant {
    address subAccount = _getSubAccount(msg.sender, _subAccountId);
    LimitOrder memory _order = limitOrders[subAccount][_orderIndex];
    // Check if this order still exists
    if (_order.account == address(0)) revert ILimitTradeHandler_NonExistentOrder();

    // Refund the execution fee to the creator of this order
    _transferOutETH(_order.executionFee, msg.sender);

    // Delete this order from the list
    delete limitOrders[subAccount][_orderIndex];

    emit CancelLimitOrder(
      msg.sender,
      _subAccountId,
      _orderIndex,
      _order.marketIndex,
      _order.sizeDelta,
      _order.triggerPrice,
      _order.triggerAboveThreshold,
      _order.executionFee,
      _order.reduceOnly
    );
  }

  /// @notice Update a limit order
  /// @param _subAccountId Sub-account Id
  /// @param _orderIndex Order Index which could be retrieved from the emitted event from `createOrder()`
  /// @param _sizeDelta How much the position size will change in USD (1e30), can be negative for INCREASE order
  /// @param _triggerPrice The price that this limit order will be triggered
  /// @param _triggerAboveThreshold The current price must go above/below the trigger price for the order to be executed
  /// @param _reduceOnly If true, it's a Reduce-Only order which will not flip the side of the position
  function updateOrder(
    uint256 _subAccountId,
    uint256 _orderIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    bool _reduceOnly
  ) external nonReentrant {
    address subAccount = _getSubAccount(msg.sender, _subAccountId);
    LimitOrder storage order = limitOrders[subAccount][_orderIndex];
    // Check if this order still exists
    if (order.account == address(0)) revert ILimitTradeHandler_NonExistentOrder();

    // Update order
    order.triggerPrice = _triggerPrice;
    order.triggerAboveThreshold = _triggerAboveThreshold;
    order.sizeDelta = _sizeDelta;
    order.reduceOnly = _reduceOnly;

    emit UpdateLimitOrder(
      msg.sender,
      _subAccountId,
      _orderIndex,
      order.sizeDelta,
      order.triggerPrice,
      order.triggerAboveThreshold,
      order.reduceOnly
    );
  }

  function validatePositionOrderPrice(
    bool _triggerAboveThreshold,
    uint256 _triggerPrice,
    uint256 _marketIndex,
    bool _maximizePrice,
    bool _revertOnError
  ) public view returns (uint256, bool) {
    // Get price from Pyth
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(ITradeService(tradeService).configStorage())
      .getMarketConfigByIndex(_marketIndex);
    IOracleMiddleware _oracle = IOracleMiddleware(IConfigStorage(ITradeService(tradeService).configStorage()).oracle());
    (uint256 _currentPrice, , uint8 _marketStatus) = _oracle.getLatestPriceWithMarketStatus(
      _marketConfig.assetId,
      _maximizePrice,
      _marketConfig.priceConfidentThreshold,
      30 // @todo retrieve price age from config
    );

    // Validate market status
    if (_marketStatus != 2) revert ILimitTradeHandler_MarketIsClosed();

    // Validate price is executable
    bool isPriceValid = _triggerAboveThreshold ? _currentPrice > _triggerPrice : _currentPrice < _triggerPrice;
    if (_revertOnError) {
      if (!isPriceValid) revert ILimitTradeHandler_InvalidPriceForExecution();
    }

    return (_currentPrice, isPriceValid);
  }

  /// @notice Transfer in ETH from user to be used as execution fee
  /// @dev The received ETH will be wrapped into WETH and store in this contract for later use.
  function _transferInETH() private {
    if (msg.value != 0) {
      IWNative(weth).deposit{ value: msg.value }();
    }
  }

  /// @notice Transfer out ETH to the receiver
  /// @dev The stored WETH will be unwrapped and transfer as native token
  /// @param _amountOut Amount of ETH to be transferred
  /// @param _receiver The receiver of ETH in its native form. The receiver must be able to accept native token.
  function _transferOutETH(uint256 _amountOut, address _receiver) private {
    IWNative(weth).withdraw(_amountOut);
    payable(_receiver).transfer(_amountOut);
  }

  /// @notice Derive sub-account from primary account and sub-account id
  function _getSubAccount(address primary, uint256 subAccountId) internal pure returns (address) {
    if (subAccountId > 255) revert ILimitTradeHandler_BadSubAccountId();
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  /// @notice Derive positionId from sub-account and market index
  function _getPositionId(address _account, uint256 _marketIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }

  function _max(uint256 x, uint256 y) internal pure returns (uint256) {
    return x < y ? y : x;
  }

  function _min(uint256 x, uint256 y) internal pure returns (uint256) {
    return x < y ? x : y;
  }
}
