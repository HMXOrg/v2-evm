// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

/// Interfaces
import { IGmxV2ExchangeRouter } from "@hmx/interfaces/gmx-v2/IGmxV2ExchangeRouter.sol";
import { IGmxV2Types } from "@hmx/interfaces/gmx-v2/IGmxV2Types.sol";
import { IGmxV2DepositCallbackReceiver } from "@hmx/interfaces/gmx-v2/IGmxV2DepositCallbackReceiver.sol";
import { IGmxV2WithdrawalCallbackReceiver } from "@hmx/interfaces/gmx-v2/IGmxV2WithdrawalCallbackReceiver.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";

contract RebalanceHLPv2Service is
  OwnableUpgradeable,
  IGmxV2DepositCallbackReceiver,
  IGmxV2WithdrawalCallbackReceiver,
  IRebalanceHLPv2Service
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  IERC20Upgradeable public weth;

  IGmxV2ExchangeRouter public gmxV2ExchangeRouter;

  address public gmxV2DepositVault;
  address public gmxV2DepositHandler;

  address public gmxV2WithdrawalVault;
  address public gmxV2WithdrawalHandler;

  mapping(bytes32 gmxOrderKey => DepositParams depositParam) depositHistory;
  mapping(bytes32 gmxOrderKey => WithdrawalParams withdrawParam) withdrawalHistory;

  event LogDepositCreated(bytes32 gmxOrderKey, DepositParams depositParam);
  event LogDepositSucceed(bytes32 gmxOrderKey, DepositParams depositParam, uint256 receivedMarketTokens);
  event LogDepositCancelled(
    bytes32 gmxOrderKey,
    DepositParams depositParam,
    uint256 returnedLongTokens,
    uint256 returnedShortTokens
  );
  event LogWithdrawalCreated(bytes32 gmxOrderKey, WithdrawalParams withdrawParam);
  event LogWithdrawalSucceed(
    bytes32 gmxOrderKey,
    WithdrawalParams withdrawParam,
    uint256 receivedLongTokens,
    uint256 receivedShortTokens
  );
  event LogWithdrawalCancelled(bytes32 gmxOrderKey, WithdrawalParams withdrawParam, uint256 returnedMarketTokens);

  function initialize(
    IERC20Upgradeable _weth,
    address _vaultStorage,
    address _configStorage,
    address _gmxV2ExchangeRouter,
    address _gmxV2DepositVault,
    address _gmxV2DepositHandler,
    address _gmxV2WithdrawalVault,
    address _gmxV2WithdrawalHandler
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    weth = _weth;
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
    gmxV2ExchangeRouter = IGmxV2ExchangeRouter(_gmxV2ExchangeRouter);
    gmxV2DepositVault = _gmxV2DepositVault;
    gmxV2DepositHandler = _gmxV2DepositHandler;
    gmxV2WithdrawalVault = _gmxV2WithdrawalVault;
    gmxV2WithdrawalHandler = _gmxV2WithdrawalHandler;
  }

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  modifier onlyGmxDepositHandler() {
    if (msg.sender != gmxV2DepositHandler) revert IRebalanceHLPv2Service_Unauthorized();
    _;
  }

  modifier onlyGmxWithdrawalHandler() {
    if (msg.sender != gmxV2WithdrawalHandler) revert IRebalanceHLPv2Service_Unauthorized();
    _;
  }

  /// @notice Create deposit orders on GMXv2 to rebalance HLP
  /// @dev Caller must approve WETH to this contract
  /// @param _depositParams Array of DepositParams
  /// @param _executionFee Execution fee in WETH
  function createDepositOrders(
    DepositParams[] calldata _depositParams,
    uint256 _executionFee
  ) external onlyWhitelisted returns (bytes32[] memory _gmxOrderKeys) {
    uint256 _depositParamsLen = _depositParams.length;
    _gmxOrderKeys = new bytes32[](_depositParamsLen);

    DepositParams memory _depositParam;
    bytes32 _gmxOrderKey;
    for (uint256 i; i < _depositParamsLen; i++) {
      _depositParam = _depositParams[i];
      if (_depositParam.longTokenAmount > 0) {
        vaultStorage.removeHLPLiquidityOnHold(_depositParam.longToken, _depositParam.longTokenAmount);
        vaultStorage.pushToken(_depositParam.longToken, gmxV2DepositVault, _depositParam.longTokenAmount);
      }
      if (_depositParam.shortTokenAmount > 0) {
        vaultStorage.removeHLPLiquidityOnHold(_depositParam.shortToken, _depositParam.shortTokenAmount);
        vaultStorage.pushToken(_depositParam.shortToken, gmxV2DepositVault, _depositParam.shortTokenAmount);
      }

      // Taken WETH from caller and send to gmxV2DepositVault for execution fee
      weth.safeTransferFrom(msg.sender, gmxV2DepositVault, _executionFee);
      // Create a deposit order
      _gmxOrderKey = gmxV2ExchangeRouter.createDeposit(
        IGmxV2ExchangeRouter.CreateDepositParams({
          receiver: address(this),
          callbackContract: address(this),
          uiFeeReceiver: address(0),
          market: _depositParam.market,
          initialLongToken: _depositParam.longToken,
          initialShortToken: _depositParam.shortToken,
          longTokenSwapPath: new address[](0),
          shortTokenSwapPath: new address[](0),
          minMarketTokens: _depositParam.minMarketTokens,
          shouldUnwrapNativeToken: false,
          executionFee: _executionFee,
          callbackGasLimit: _depositParam.gasLimit
        })
      );
      _gmxOrderKeys[i] = _gmxOrderKey;
      depositHistory[_gmxOrderKey] = _depositParam;

      emit LogDepositCreated(_gmxOrderKey, _depositParam);
    }
  }

  /// @notice Create withdraw orders on GMXv2 to rebalance HLP
  /// @dev Caller must approve WETH to this contract
  /// @param _withdrawParams Array of WithdrawParams
  /// @param _executionFee Execution fee in WETH
  function createWithdrawalOrders(
    WithdrawalParams[] calldata _withdrawParams,
    uint256 _executionFee
  ) external onlyWhitelisted returns (bytes32[] memory _gmxOrderKeys) {
    uint256 _withdrawParamsLen = _withdrawParams.length;
    _gmxOrderKeys = new bytes32[](_withdrawParamsLen);

    WithdrawalParams memory _withdrawParam;
    bytes32 _gmxOrderKey;
    for (uint256 i = 0; i < _withdrawParamsLen; ) {
      _withdrawParam = _withdrawParams[i];

      // Remove GM(x), accounted as on hold, and send to gmxV2DepositVault.
      vaultStorage.removeHLPLiquidityOnHold(_withdrawParam.market, _withdrawParam.amount);
      vaultStorage.pushToken(_withdrawParam.market, gmxV2WithdrawalVault, _withdrawParam.amount);

      // Taken WETH from caller and send to gmxV2DepositVault for execution fee
      weth.safeTransferFrom(msg.sender, gmxV2WithdrawalVault, _executionFee);
      // Create a withdrawal order
      _gmxOrderKey = gmxV2ExchangeRouter.createWithdrawal(
        IGmxV2ExchangeRouter.CreateWithdrawalParams({
          receiver: address(this),
          callbackContract: address(this),
          uiFeeReceiver: address(0),
          market: _withdrawParam.market,
          longTokenSwapPath: new address[](0),
          shortTokenSwapPath: new address[](0),
          minLongTokenAmount: _withdrawParam.minLongTokenAmount,
          minShortTokenAmount: _withdrawParam.minShortTokenAmount,
          shouldUnwrapNativeToken: false,
          executionFee: _executionFee,
          callbackGasLimit: _withdrawParam.gasLimit
        })
      );
      _gmxOrderKeys[i] = _gmxOrderKey;
      withdrawalHistory[_gmxOrderKey] = _withdrawParam;

      emit LogWithdrawalCreated(_gmxOrderKey, _withdrawParam);

      unchecked {
        ++i;
      }
    }
  }

  /// @notice Called by GMXv2 after a deposit execution
  /// @param key The key of the deposit
  /// @param eventData The event data emitted by GMXv2
  function afterDepositExecution(
    bytes32 key,
    IGmxV2Types.DepositProps memory /* deposit */,
    IGmxV2Types.EventLogData memory eventData
  ) external onlyGmxDepositHandler {
    DepositParams memory depositParam = depositHistory[key];
    if (depositParam.longToken == address(0) || depositParam.shortToken == address(0))
      revert IRebalanceHLPv2Service_KeyNotFound();

    // Add recieved GMs as liquidity
    uint256 receivedGms = eventData.uintItems.items[0].value;
    if (receivedGms == 0) revert IRebalanceHLPv2Service_ZeroGmReceived();
    IERC20Upgradeable(depositParam.market).safeTransfer(address(vaultStorage), receivedGms);
    vaultStorage.pullToken(depositParam.market);
    vaultStorage.addHLPLiquidity(depositParam.market, receivedGms);

    // Clear on hold long token
    if (depositParam.longTokenAmount > 0) {
      vaultStorage.clearOnHold(depositParam.longToken, depositParam.longTokenAmount);
    }

    // Clear on hold short token
    if (depositParam.shortTokenAmount > 0) {
      vaultStorage.clearOnHold(depositParam.shortToken, depositParam.shortTokenAmount);
    }

    emit LogDepositSucceed(key, depositParam, receivedGms);

    // Clear deposit history
    delete depositHistory[key];
  }

  /// @notice Called by GMXv2 if a deposit was cancelled/reverted
  /// @param key the key of the deposit
  function afterDepositCancellation(
    bytes32 key,
    IGmxV2Types.DepositProps memory /* deposit */,
    IGmxV2Types.EventLogData memory /* eventData */
  ) external onlyGmxDepositHandler {
    // Check
    DepositParams memory depositParam = depositHistory[key];
    if (depositParam.longToken == address(0) || depositParam.shortToken == address(0))
      revert IRebalanceHLPv2Service_KeyNotFound();

    // Effect
    uint256 pulled = 0;

    // Clear on hold long token
    if (depositParam.longTokenAmount > 0) {
      vaultStorage.clearOnHold(depositParam.longToken, depositParam.longTokenAmount);
      IERC20Upgradeable(depositParam.longToken).safeTransfer(address(vaultStorage), depositParam.longTokenAmount);
      pulled = vaultStorage.pullToken(depositParam.longToken);
      vaultStorage.addHLPLiquidity(depositParam.longToken, pulled);
    }

    // Clear on hold short token
    if (depositParam.shortTokenAmount > 0) {
      vaultStorage.clearOnHold(depositParam.shortToken, depositParam.shortTokenAmount);
      IERC20Upgradeable(depositParam.longToken).safeTransfer(address(vaultStorage), depositParam.shortTokenAmount);
      pulled = vaultStorage.pullToken(depositParam.shortToken);
      vaultStorage.addHLPLiquidity(depositParam.shortToken, pulled);
    }

    delete depositHistory[key];

    // Log
    emit LogDepositCancelled(key, depositParam, depositParam.longTokenAmount, depositParam.shortTokenAmount);
  }

  /// @notice Called by GMXv2 after a withdrawal execution
  function afterWithdrawalExecution(
    bytes32 _key,
    IGmxV2Types.WithdrawalProps memory,
    IGmxV2Types.EventLogData memory _eventData
  ) external override onlyGmxWithdrawalHandler {
    // Check
    WithdrawalParams memory _withdrawParam = withdrawalHistory[_key];
    if (_withdrawParam.market == address(0)) revert IRebalanceHLPv2Service_KeyNotFound();

    // Effect
    // Add received long as liquidity
    uint256 _receivedLong = _eventData.uintItems.items[0].value;
    if (_receivedLong > 0) {
      IERC20Upgradeable(_eventData.addressItems.items[0].value).safeTransfer(address(vaultStorage), _receivedLong);
      vaultStorage.pullToken(_eventData.addressItems.items[0].value);
      vaultStorage.addHLPLiquidity(_eventData.addressItems.items[0].value, _receivedLong);
    }

    // Add received short as liquidity
    uint256 _receivedShort = _eventData.uintItems.items[1].value;
    if (_receivedShort > 0) {
      IERC20Upgradeable(_eventData.addressItems.items[1].value).safeTransfer(address(vaultStorage), _receivedShort);
      vaultStorage.pullToken(_eventData.addressItems.items[1].value);
      vaultStorage.addHLPLiquidity(_eventData.addressItems.items[1].value, _receivedShort);
    }

    // Clear on hold GM(x)
    vaultStorage.clearOnHold(_withdrawParam.market, _withdrawParam.amount);
    // Clear withdrawal history
    delete withdrawalHistory[_key];

    emit LogWithdrawalSucceed(_key, _withdrawParam, _receivedLong, _receivedShort);
  }

  /// @notice Called by GMXv2 if a withdrawal was cancelled/reverted
  function afterWithdrawalCancellation(
    bytes32 _key,
    IGmxV2Types.WithdrawalProps memory,
    IGmxV2Types.EventLogData memory
  ) external override onlyGmxWithdrawalHandler {
    // Check
    WithdrawalParams memory _withdrawParam = withdrawalHistory[_key];
    if (_withdrawParam.market == address(0)) revert IRebalanceHLPv2Service_KeyNotFound();

    // Clear GM(x) on hold and update HLP liquidity
    vaultStorage.clearOnHold(_withdrawParam.market, _withdrawParam.amount);
    IERC20Upgradeable(_withdrawParam.market).safeTransfer(address(vaultStorage), _withdrawParam.amount);
    uint256 _pulled = vaultStorage.pullToken(_withdrawParam.market);
    vaultStorage.addHLPLiquidity(_withdrawParam.market, _pulled);

    // Clear withdrawal history
    delete withdrawalHistory[_key];

    // Log
    emit LogWithdrawalCancelled(_key, _withdrawParam, _pulled);
  }

  /// @notice Get deposit history
  /// @param _key The key of the deposit
  /// @return DepositParams
  function getDepositHistory(bytes32 _key) external view override returns (DepositParams memory) {
    return depositHistory[_key];
  }

  /// @notice Get withdrawal history
  /// @param _key The key of the withdrawal
  /// @return WithdrawalParams
  function getWithdrawalHistory(bytes32 _key) external view override returns (WithdrawalParams memory) {
    return withdrawalHistory[_key];
  }

  /// @notice Claim returned ETH from GMXv2.
  /// @dev This is likely unused execution fee.
  function claimETH() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /// @notice Receive unspent execution fee from GMXv2
  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
