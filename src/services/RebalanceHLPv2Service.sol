// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

/// Interfaces
import { IGmxExchangeRouter } from "@hmx/interfaces/gmx-v2/IGmxExchangeRouter.sol";
import { IDepositCallbackReceiver, EventUtils, Deposit } from "@hmx/interfaces/gmx-v2/IDepositCallbackReceiver.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";

import { console2 } from "forge-std/console2.sol";

contract RebalanceHLPv2Service is OwnableUpgradeable, IDepositCallbackReceiver, IRebalanceHLPv2Service {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  IGmxExchangeRouter public exchangeRouter;
  IERC20Upgradeable public weth;
  address public depositVault;
  address public depositHandler;
  uint16 public minHLPValueLossBPS;

  mapping(bytes32 gmxOrderKey => DepositParams depositParam) depositHistory;

  modifier onlyWhitelisted() {
    configStorage.validateServiceExecutor(address(this), msg.sender);
    _;
  }

  modifier onlyGmxDepositHandler() {
    if (msg.sender != depositHandler) revert IRebalanceHLPv2Service_Unauthorized();
    _;
  }

  event LogDepositCreated(bytes32 gmxOrderKey, DepositParams depositParam);
  event LogDepositSucceed(bytes32 gmxOrderKey, DepositParams depositParam, uint256 receivedMarketTokens);
  event LogDepositCancelled(
    bytes32 gmxOrderKey,
    DepositParams depositParam,
    uint256 returnedLongTokens,
    uint256 returnedShortTokens
  );
  event LogSetMinHLPValueLossBPS(uint16 oldValue, uint16 newValue);

  function initialize(
    IERC20Upgradeable _weth,
    address _vaultStorage,
    address _configStorage,
    address _exchangeRouter,
    address _depositVault,
    address _depositHandler,
    uint16 _minHLPValueLossBPS
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    weth = _weth;
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
    exchangeRouter = IGmxExchangeRouter(_exchangeRouter);
    depositVault = _depositVault;
    depositHandler = _depositHandler;
    minHLPValueLossBPS = _minHLPValueLossBPS;
  }

  /// @notice Create deposit orders on GMXv2 to rebalance HLP
  /// @dev Caller must approve WETH to this contract
  /// @param _depositParams Array of DepositParams
  /// @param _executionFee Execution fee in WETH
  function createDepositOrders(
    DepositParams[] calldata _depositParams,
    uint256 _executionFee
  ) external onlyWhitelisted returns (bytes32[] memory gmxOrderKeys) {
    uint256 _depositParamsLen = _depositParams.length;
    gmxOrderKeys = new bytes32[](_depositParamsLen);

    for (uint256 i; i < _depositParamsLen; i++) {
      DepositParams memory _depositParam = _depositParams[i];
      if (_depositParam.longTokenAmount > 0) {
        vaultStorage.removeHLPLiquidityOnHold(_depositParam.longToken, _depositParam.longTokenAmount);
        vaultStorage.pushToken(_depositParam.longToken, address(depositVault), _depositParam.longTokenAmount);
      }
      if (_depositParam.shortTokenAmount > 0) {
        vaultStorage.removeHLPLiquidityOnHold(_depositParam.shortToken, _depositParam.shortTokenAmount);
        vaultStorage.pushToken(_depositParam.shortToken, address(depositVault), _depositParam.shortTokenAmount);
      }

      // Taken WETH from caller and send to depositVault for execution fee
      weth.safeTransferFrom(msg.sender, address(depositVault), _executionFee);
      bytes32 gmxOrderKey = exchangeRouter.createDeposit(
        IGmxExchangeRouter.CreateDepositParams({
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
      gmxOrderKeys[i] = gmxOrderKey;
      depositHistory[gmxOrderKey] = _depositParam;

      emit LogDepositCreated(gmxOrderKey, _depositParam);
    }
  }

  /// @notice Called by GMXv2 after a deposit execution
  /// @param key The key of the deposit
  /// @param eventData The event data emitted by GMXv2
  function afterDepositExecution(
    bytes32 key,
    Deposit.Props memory /* deposit */,
    EventUtils.EventLogData memory eventData
  ) external onlyGmxDepositHandler {
    DepositParams memory depositParam = depositHistory[key];
    if (depositParam.longToken == address(0) && depositParam.shortToken == address(0))
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
    Deposit.Props memory /* deposit */,
    EventUtils.EventLogData memory /* eventData */
  ) external onlyGmxDepositHandler {
    // Clear on hold long token
    uint256 pulled = 0;
    DepositParams memory depositParam = depositHistory[key];
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

    emit LogDepositCancelled(key, depositParam, depositParam.longTokenAmount, depositParam.shortTokenAmount);

    delete depositHistory[key];
  }

  // function _validateHLPValue(uint256 _valueBefore) internal view {
  //   uint256 hlpValue = calculator.getHLPValueE30(true);
  //   if (_valueBefore > hlpValue) {
  //     uint256 diff = _valueBefore - hlpValue;
  //     /**
  //     EQ:  ( Before - After )          minHLPValueLossBPS
  //           ----------------     >      ----------------
  //               Before                        BPS

  //     To reduce the div,   ( Before - After ) * (BPS**2) = minHLPValueLossBPS * Before
  //      */
  //     if ((diff * 1e4) > (minHLPValueLossBPS * _valueBefore)) {
  //       revert RebalanceHLPService_HlpTvlDropExceedMin();
  //     }
  //   }
  // }

  function setMinHLPValueLossBPS(uint16 _hlpValueLossBPS) external onlyOwner {
    if (_hlpValueLossBPS == 0) {
      revert IRebalanceHLPv2Service_AmountIsZero();
    }
    emit LogSetMinHLPValueLossBPS(minHLPValueLossBPS, _hlpValueLossBPS);
    minHLPValueLossBPS = _hlpValueLossBPS;
  }

  function claimETH() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /// Receive unspent execution fee from GMXv2
  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
