// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Bases
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

/// Interfaces
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";

/// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

/// Storages
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";

/// Libs
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

/// @title Ext01Handler - Handler for extended actions which not related to core functionality.
contract Ext01Handler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IExt01Handler {
  event LogSwitchCollateral(
    address indexed primaryAccount,
    uint256 indexed subAccountId,
    address[] path,
    uint256 fromAmount,
    uint256 toAmount
  );
  event LogCreateSwitchCollateralOrder(
    address indexed primaryAccount,
    uint8 indexed subAccountId,
    uint248 amount,
    address[] path,
    uint256 minToAmount
  );
  event LogSetCrossMarginService(
    CrossMarginService indexed prevCrossMarginService,
    CrossMarginService indexed newCrossMarginService
  );
  event LogSetLiquidationService(
    LiquidationService indexed oldLiquidationService,
    LiquidationService indexed newLiquidationService
  );
  event LogSetLiquidityService(
    LiquidityService indexed oldLiquidityService,
    LiquidityService indexed newLiquidityService
  );
  event LogMaxExecutionChuck(uint256 prevMaxExecutionChuck, uint256 newMaxExecutionChuck);
  event LogSetMinExecutionFee(uint24 indexed orderType, uint256 prevMinExecutionFee, uint256 newMinExecutionFee);
  event LogSetOrderExecutor(address indexed executor, bool prevIsAllow, bool isAllow);
  event LogSetPyth(IEcoPyth indexed prevPyth, IEcoPyth indexed newPyth);
  event LogSetTradeService(TradeService indexed oldTradeService, TradeService indexed newTradeService);
  event LogExecuteOrderResult(
    uint256 indexed orderId,
    uint24 orderType,
    uint128 executionFee,
    bool isSuccess,
    string errMsg
  );

  /**
   * Configuration States
   */
  CrossMarginService public crossMarginService;
  LiquidationService public liquidationService;
  LiquidityService public liquidityService;
  TradeService public tradeService;
  IEcoPyth public pyth;

  /**
   * Storage States
   */
  uint256 public nextExecutionOrderIndex; // The index of the next executable order that should be executed
  mapping(uint24 orderType => uint128 minExecutionFee) public minExecutionOrderOf; // Minimum execution fee of each orderType
  uint256 public maxExecutionChuck; // Maximum execution order sizes per request

  GenericOrder[] public orders; // All extended orders
  mapping(address => bool) public orderExecutors; // address -> flag to execute

  /// @notice Validate only whitelisted executors to call function
  modifier onlyOrderExecutor() {
    if (!orderExecutors[msg.sender]) revert IExt01Handler_Unauthorized();
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initialize the Ext01Handler with the provided configuration parameters.
  /// @param _crossMarginService Address of the CrossMarginService contract.
  /// @param _liquidationService Address of the LiquidationService contract.
  /// @param _liquidityService Address of the LiquidityService contract.
  /// @param _tradeService Address of the TradeService contract.
  /// @param _pyth Address of the Pyth contract.
  function initialize(
    address _crossMarginService,
    address _liquidationService,
    address _liquidityService,
    address _tradeService,
    address _pyth,
    uint256 _maxExecutionChuck
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    crossMarginService = CrossMarginService(_crossMarginService);
    liquidationService = LiquidationService(_liquidationService);
    liquidityService = LiquidityService(_liquidityService);
    tradeService = TradeService(_tradeService);
    pyth = IEcoPyth(_pyth);

    maxExecutionChuck = _maxExecutionChuck;

    // Sanity check
    crossMarginService.vaultStorage();
    liquidationService.vaultStorage();
    liquidityService.vaultStorage();
    tradeService.vaultStorage();
    pyth.getAssetIds();
  }

  struct CreateSwitchCollateralOrderParams {
    uint8 subAccountId;
    uint248 amount;
    address[] path;
    uint256 minToAmount;
  }

  /**
   * Main routines
   */

  function createExtOrder(
    CreateExtOrderParams memory _params
  ) external payable nonReentrant returns (uint256 _orderId) {
    // Check
    // 0 = Cancelled order
    if (_params.orderType == 0) revert IExt01Handler_BadOrderType();
    uint128 _minExecutionFee = minExecutionOrderOf[_params.orderType];
    if (_params.executionFee < _minExecutionFee) revert IExt01Handler_InsufficientExecutionFee();
    if (msg.value != _minExecutionFee) revert IExt01Handler_InCorrectValueTransfer();

    // Convert native to wrapped native.
    // This should just only a executionFee
    _transferInETH();

    _orderId = orders.length;
    bytes memory _rawOrder;

    // Create order according to the command
    if (_params.orderType == 1) {
      // OrderType 1 = Create switch collateral order
      CreateSwitchCollateralOrderParams memory _localVars;
      (_localVars.subAccountId, _localVars.amount, _localVars.path, _localVars.minToAmount) = abi.decode(
        _params.data,
        (uint8, uint248, address[], uint256)
      );
      _rawOrder = _createSwitchCollateralOrder(
        _localVars.subAccountId,
        _localVars.amount,
        _localVars.path,
        _localVars.minToAmount
      );
    }

    orders.push(
      GenericOrder({
        orderId: uint248(_orderId),
        status: OrderStatus.PENDING,
        createdTimestamp: uint48(block.timestamp),
        executedTimestamp: 0,
        orderType: uint24(_params.orderType),
        executionFee: uint128(0),
        rawOrder: _rawOrder
      })
    );
  }

  function executeOrders(
    uint256 _endIndex,
    address payable _feeReceiver,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external nonReentrant onlyOrderExecutor {
    // SLOAD
    uint256 _nextExecutionOrderIndex = nextExecutionOrderIndex;

    // Get the number of ext orders
    uint256 _orderLength = orders.length;

    // Ensure there are orders to execute
    if (_nextExecutionOrderIndex == _orderLength) revert IExt01Handler_NoOrder();

    // Set the end index to the latest order index if it exceeds the number of orders
    uint256 _latestOrderIndex = _orderLength - 1;
    if (_endIndex > _latestOrderIndex) {
      _endIndex = _latestOrderIndex;
    }

    // split execution into chunk for preventing exceed block gas limit
    if (_endIndex - _nextExecutionOrderIndex > maxExecutionChuck)
      _endIndex = _nextExecutionOrderIndex + maxExecutionChuck;

    // Update the price and publish time data using the Pyth oracle
    IEcoPyth(pyth).updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    // Initialize variables for the execution loop
    GenericOrder memory _order;
    uint128 _totalFeeReceived;
    uint128 _executionFee;

    for (uint256 i = _nextExecutionOrderIndex; i <= _endIndex; ) {
      _order = orders[i];

      // Skip cancelled order
      if (_order.orderType == 0) {
        unchecked {
          ++i;
        }
        continue;
      }

      _executionFee = _order.executionFee;

      try this.executeOrder(_order) {
        emit LogExecuteOrderResult(_order.orderId, _order.orderType, _order.executionFee, true, "");
        // update order status
        _order.status = OrderStatus.SUCCESS;
      } catch Error(string memory errMsg) {
        _handleFailedError(_order, errMsg);
      } catch Panic(uint /*errorCode*/) {
        _handleFailedError(_order, "Panic occurred while executing the switch collateral order");
      } catch (bytes memory errMsg) {
        _handleFailedError(_order, string(errMsg));
      }

      // Assign execution time
      _order.executedTimestamp = uint48(block.timestamp);
      _totalFeeReceived += _executionFee;

      // Clear executed switch collateral order
      delete orders[i];

      unchecked {
        ++i;
      }
    }

    nextExecutionOrderIndex = _endIndex + 1;
    // Pay execution fee to the executor
    _transferOutETH(_totalFeeReceived, _feeReceiver);
  }

  function executeOrder(GenericOrder memory _order) external {
    // If not in executing state, then revert
    if (msg.sender != address(this)) revert IExt01Handler_Unauthorized();

    if (_order.orderType == 1) {
      // OrderType 1 == Switch collateral order
      SwitchCollateralOrder memory _switchCollateralOrder = abi.decode(_order.rawOrder, (SwitchCollateralOrder));
      _executeSwitchCollateralOrder(_switchCollateralOrder);
    }
  }

  function _handleFailedError(GenericOrder memory _order, string memory errMsg) internal {
    emit LogExecuteOrderResult(_order.orderId, _order.orderType, _order.executionFee, false, errMsg);
    _order.status = OrderStatus.FAIL;
  }

  /**
   * Switch Collateral
   */

  /// @notice Creates a new switch collateral order to facilitate the switch of collateral token from one to another.
  /// @param _subAccountId ID of the user's sub-account.
  /// @param _amount Amount of path[0] to switch.
  /// @param _path Path of the switch collateral.
  /// @param _minToAmount Minimum amount to be received.
  function _createSwitchCollateralOrder(
    uint8 _subAccountId,
    uint248 _amount,
    address[] memory _path,
    uint256 _minToAmount
  ) internal returns (bytes memory _rawOrder) {
    // Check
    (address _fromToken, address _toToken) = (_path[0], _path[_path.length - 1]);
    _revertOnNotAcceptedCollateral(_fromToken);
    _revertOnNotAcceptedCollateral(_toToken);
    if (_amount == 0) revert IExt01Handler_BadAmount();
    if (_fromToken == _toToken) revert IExt01Handler_SameFromToToken();

    emit LogCreateSwitchCollateralOrder(msg.sender, _subAccountId, _amount, _path, _minToAmount);

    _rawOrder = abi.encode(
      SwitchCollateralOrder({
        primaryAccount: msg.sender,
        subAccountId: _subAccountId,
        amount: _amount,
        path: _path,
        minToAmount: _minToAmount,
        crossMarginService: crossMarginService
      })
    );
  }

  function _executeSwitchCollateralOrder(SwitchCollateralOrder memory _order) internal {
    // Call service to switch collateral
    uint256 _toAmount = _order.crossMarginService.switchCollateral(
      ICrossMarginService.SwitchCollateralParams(
        _order.primaryAccount,
        _order.subAccountId,
        _order.amount,
        _order.path,
        _order.minToAmount
      )
    );

    emit LogSwitchCollateral(_order.primaryAccount, _order.subAccountId, _order.path, _order.amount, _toAmount);
  }

  /// @notice Returns all pending extended orders.
  /// @return _extOrders An array of extended orders.
  function getOrders() external view returns (GenericOrder[] memory _extOrders) {
    return orders;
  }

  /// @notice Get order length.
  function getOrderLength() external view returns (uint256) {
    return orders.length;
  }

  /**
   * Private Functions
   */

  /// @notice Transfer in ETH from user to be used as execution fee
  /// @dev The received ETH will be wrapped into WETH and store in this contract for later use.
  function _transferInETH() internal {
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
    // To mitigate potential attacks, the call method is utilized,
    // allowing the contract to bypass any revert calls from the destination address.
    // By setting the gas limit to 2300, equivalent to the gas limit of the transfer method,
    // the transaction maintains a secure execution."
    (bool success, ) = _receiver.call{ value: _amountOut, gas: 2300 }("");
    // send WNative instead when native token transfer fail
    if (!success) {
      address weth = ConfigStorage(CrossMarginService(crossMarginService).configStorage()).weth();
      IWNative(weth).deposit{ value: _amountOut }();
      IWNative(weth).transfer(_receiver, _amountOut);
    }
  }

  /// @notice Validate only accepted collateral tokens
  function _revertOnNotAcceptedCollateral(address _token) internal view {
    ConfigStorage(CrossMarginService(crossMarginService).configStorage()).validateAcceptedCollateral(_token);
  }

  receive() external payable {
    // @dev Cannot enable this check due to Solidity Fallback Function Gas Limit introduced in 0.8.17.
    // ref - https://stackoverflow.com/questions/74930609/solidity-fallback-function-gas-limit
  }

  /*
   * Setters
   */

  /// @notice Sets a new CrossMarginService contract address.
  /// @param _crossMarginService The new CrossMarginService contract address.
  function setCrossMarginService(address _crossMarginService) external onlyOwner {
    if (_crossMarginService == address(0)) revert IExt01Handler_BadAddress();
    emit LogSetCrossMarginService(crossMarginService, CrossMarginService(_crossMarginService));
    crossMarginService = CrossMarginService(_crossMarginService);

    // Sanity check
    crossMarginService.vaultStorage();
  }

  /// @notice Set a new LiquidationService
  /// @param _liquidationService The new LiquidationService contract address.
  function setLiquidationService(address _liquidationService) external onlyOwner {
    if (_liquidationService == address(0)) revert IExt01Handler_BadAddress();
    emit LogSetLiquidationService(liquidationService, LiquidationService(_liquidationService));
    liquidationService = LiquidationService(_liquidationService);

    // Sanity check
    liquidationService.vaultStorage();
  }

  /// @notice Set a new LiquidityService
  /// @param _liquidityService The new LiquidityService contract address.
  function setLiquidityService(address _liquidityService) external onlyOwner {
    if (_liquidityService == address(0)) revert IExt01Handler_BadAddress();
    emit LogSetLiquidityService(liquidityService, LiquidityService(_liquidityService));
    liquidityService = LiquidityService(_liquidityService);

    // Sanity check
    liquidityService.vaultStorage();
  }

  /// @notice Set a new TradeService
  /// @param _tradeService The new TradeService contract address.
  function setTradeService(address _tradeService) external onlyOwner {
    if (_tradeService == address(0)) revert IExt01Handler_BadAddress();
    emit LogSetTradeService(tradeService, TradeService(_tradeService));
    tradeService = TradeService(_tradeService);

    // Sanity check
    tradeService.vaultStorage();
  }

  /// @notice Sets a new Pyth contract address.
  /// @param _pyth The new Pyth contract address.
  function setPyth(address _pyth) external onlyOwner {
    if (_pyth == address(0)) revert IExt01Handler_BadAddress();
    emit LogSetPyth(pyth, IEcoPyth(_pyth));
    pyth = IEcoPyth(_pyth);

    // Sanity check
    IEcoPyth(_pyth).getAssetIds();
  }

  /// @notice setMinExecutionFee
  /// @param _orderType Order type to set min execution fee
  /// @param _newMinExecutionFee minExecutionFee in ethers
  function setMinExecutionFee(uint24 _orderType, uint128 _newMinExecutionFee) external nonReentrant onlyOwner {
    emit LogSetMinExecutionFee(_orderType, minExecutionOrderOf[_orderType], _newMinExecutionFee);
    minExecutionOrderOf[_orderType] = _newMinExecutionFee;
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
  function setOrderExecutor(address _executor, bool _isAllow) external onlyOwner {
    emit LogSetOrderExecutor(_executor, orderExecutors[_executor], _isAllow);
    orderExecutors[_executor] = _isAllow;
  }
}
