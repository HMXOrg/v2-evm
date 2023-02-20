// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Owned } from "../base/Owned.sol";

// Interfaces
import { IWNative } from "../interfaces/IWNative.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { ITradeService } from "../services/interfaces/ITradeService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";

contract LimitTradeHandler is Owned, ReentrancyGuard {
  //ERRORS
  error ILimitTradeHandler_InvalidAddress();
  error ILimitTradeHandler_InsufficientExecutionFee();
  error ILimitTradeHandler_IncorrectValueTransfer();
  error ILimitTradeHandler_NotWhitelisted();
  error ILimitTradeHandler_BadSubAccountId();
  error ILimitTradeHandler_InvalidSender();
  error ILimitTradeHandler_NonExistentOrder();
  error ILimitTradeHandler_MarketIsClose();
  error ILimitTradeHandler_InvalidPriceForExecution();

  // EVENTS
  event LogSetTradeService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);

  // STATES
  struct IncreaseOrder {
    address account;
    uint256 subAccountId;
    uint256 marketIndex;
    int256 sizeDelta;
    bool isLong;
    uint256 triggerPrice;
    bool triggerAboveThreshold;
    uint256 executionFee;
  }
  struct DecreaseOrder {
    address account;
    uint256 subAccountId;
    uint256 marketIndex;
    uint256 sizeDelta;
    bool isLong;
    uint256 triggerPrice;
    bool triggerAboveThreshold;
    uint256 executionFee;
  }

  mapping(address => mapping(uint256 => IncreaseOrder)) public increaseOrders;
  mapping(address => uint256) public increaseOrdersIndex;
  mapping(address => mapping(uint256 => DecreaseOrder)) public decreaseOrders;
  mapping(address => uint256) public decreaseOrdersIndex;

  address public weth;
  ITradeService public tradeService;
  IPyth public pyth;
  IOracleMiddleware public oracle;
  uint256 public minExecutionFee;
  mapping(address => bool) public orderExecutors;
  bool public isAllowAllExecutor;

  constructor(
    address _weth,
    address _tradeService,
    address _pyth,
    address _oracle,
    uint256 _minExecutionFee
  ) {
    // @todo - Sanity check
    weth = _weth;
    tradeService = ITradeService(_tradeService);
    pyth = IPyth(_pyth);
    oracle = IOracleMiddleware(_oracle);
    minExecutionFee = _minExecutionFee;
  }

  receive() external payable {
    if (msg.sender != weth) revert ILimitTradeHandler_InvalidSender();
  }

  // Only whitelisted addresses can be able to execute limit orders
  modifier onlyOrderExecutor() {
    if (!isAllowAllExecutor && !orderExecutors[msg.sender])
      revert ILimitTradeHandler_NotWhitelisted();
    _;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER
  ////////////////////////////////////////////////////////////////////////////////////

  function setTradeService(address _newTradeService) external onlyOwner {
    // @todo - Sanity check
    if (_newTradeService == address(0))
      revert ILimitTradeHandler_InvalidAddress();
    emit LogSetTradeService(address(tradeService), _newTradeService);
    tradeService = ITradeService(_newTradeService);
  }

  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  ////////////////////// CALCULATION
  ////////////////////////////////////////////////////////////////////////////////////

  function createIncreaseOrder(
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee
  ) external payable nonReentrant {
    // Transfer in the native token to be used as execution fee
    _transferInETH();

    if (_executionFee < minExecutionFee)
      revert ILimitTradeHandler_InsufficientExecutionFee();
    if (msg.value != _executionFee)
      revert ILimitTradeHandler_IncorrectValueTransfer();

    address _subAccount = _getSubAccount(msg.sender, _subAccountId);
    uint256 _orderIndex = increaseOrdersIndex[_subAccount];

    IncreaseOrder memory _order = IncreaseOrder(
      msg.sender,
      _subAccountId,
      _marketIndex,
      _sizeDelta,
      _sizeDelta > 0, // isLong
      _triggerPrice,
      _triggerAboveThreshold,
      _executionFee
    );
    increaseOrdersIndex[_subAccount] = _orderIndex + 1;
    increaseOrders[_subAccount][_orderIndex] = _order;
  }

  function createDecreaseOrder(
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _sizeDelta,
    uint256 _triggerPrice,
    bool _triggerAboveThreshold,
    uint256 _executionFee
  ) external payable nonReentrant {
    // Transfer in the native token to be used as execution fee
    _transferInETH();

    if (_executionFee < minExecutionFee)
      revert ILimitTradeHandler_InsufficientExecutionFee();
    if (msg.value != _executionFee)
      revert ILimitTradeHandler_IncorrectValueTransfer();

    address _subAccount = _getSubAccount(msg.sender, _subAccountId);
    uint256 _orderIndex = decreaseOrdersIndex[_subAccount];

    bytes32 _positionId = _getPositionId(_subAccount, _marketIndex);

    DecreaseOrder memory _order = DecreaseOrder(
      msg.sender,
      _subAccountId,
      _marketIndex,
      _sizeDelta,
      IPerpStorage(tradeService.perpStorage())
        .getPositionById(_positionId)
        .positionSizeE30 > 0, // isLong
      _triggerPrice,
      _triggerAboveThreshold,
      _executionFee
    );
    decreaseOrdersIndex[_subAccount] = _orderIndex + 1;
    decreaseOrders[_subAccount][_orderIndex] = _order;
  }

  function executeIncreaseOrder(
    address _address,
    uint256 _subAccountId,
    uint256 _orderIndex,
    address payable _feeReceiver,
    bytes[] memory _priceData
  ) external nonReentrant onlyOrderExecutor {
    address _subAccount = _getSubAccount(_address, _subAccountId);
    IncreaseOrder memory order = increaseOrders[_subAccount][_orderIndex];
    if (order.account == address(0))
      revert ILimitTradeHandler_NonExistentOrder();

    // Update price to Pyth
    pyth.updatePriceFeeds{ value: pyth.getUpdateFee(_priceData) }(_priceData);

    (uint256 _currentPrice, ) = validatePositionOrderPrice(
      order.triggerAboveThreshold,
      order.triggerPrice,
      order.marketIndex,
      order.isLong,
      true
    );

    delete increaseOrders[_subAccount][_orderIndex];

    // @todo waiting for increasePosition to finish
    // tradeService.increasePosition();

    // pay executor
    _transferOutETH(order.executionFee, _feeReceiver);
  }

  function executeDecreaseOrder(
    address _account,
    uint256 _subAccountId,
    uint256 _orderIndex,
    address payable _feeReceiver,
    bytes[] memory _priceData
  ) external nonReentrant onlyOrderExecutor {
    address _subAccount = _getSubAccount(_account, _subAccountId);
    DecreaseOrder memory order = decreaseOrders[_subAccount][_orderIndex];
    if (order.account == address(0))
      revert ILimitTradeHandler_NonExistentOrder();

    // Update price to Pyth
    pyth.updatePriceFeeds{ value: pyth.getUpdateFee(_priceData) }(_priceData);

    (uint256 _currentPrice, ) = validatePositionOrderPrice(
      order.triggerAboveThreshold,
      order.triggerPrice,
      order.marketIndex,
      order.isLong,
      true
    );

    delete decreaseOrders[_subAccount][_orderIndex];

    tradeService.decreasePosition(
      _account,
      _subAccountId,
      order.marketIndex,
      order.sizeDelta
    );

    // pay executor
    _transferOutETH(order.executionFee, _feeReceiver);
  }

  function validatePositionOrderPrice(
    bool _triggerAboveThreshold,
    uint256 _triggerPrice,
    uint256 _marketIndex,
    bool _maximizePrice,
    bool _revertOnError
  ) public view returns (uint256, bool) {
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      tradeService.configStorage()
    ).getMarketConfigByIndex(_marketIndex);

    (uint256 _currentPrice, , uint8 _marketStatus) = oracle
      .getLatestPriceWithMarketStatus(
        _marketConfig.assetId,
        _maximizePrice,
        _marketConfig.priceConfidentThreshold,
        30 // @todo retrieve price age from config
      );
    if (_marketStatus != 2) revert ILimitTradeHandler_MarketIsClose();
    bool isPriceValid = _triggerAboveThreshold
      ? _currentPrice > _triggerPrice
      : _currentPrice < _triggerPrice;
    if (_revertOnError) {
      if (!isPriceValid) revert ILimitTradeHandler_InvalidPriceForExecution();
    }
    return (_currentPrice, isPriceValid);
  }

  function _transferInETH() private {
    if (msg.value != 0) {
      IWNative(weth).deposit{ value: msg.value }();
    }
  }

  function _transferOutETH(uint256 _amountOut, address _receiver) private {
    IWNative(weth).withdraw(_amountOut);
    payable(_receiver).transfer(_amountOut);
  }

  function _getSubAccount(
    address primary,
    uint256 subAccountId
  ) internal pure returns (address) {
    if (subAccountId > 255) revert ILimitTradeHandler_BadSubAccountId();
    return address(uint160(primary) ^ uint160(subAccountId));
  }

  function _getPositionId(
    address _account,
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }
}
