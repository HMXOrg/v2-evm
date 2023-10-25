// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// libs
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// interfaces
import { IGmxExchangeRouter } from "@hmx/interfaces/gmx-v2/IGmxExchangeRouter.sol";
import { IDepositCallbackReceiver, EventUtils, Deposit } from "@hmx/interfaces/gmx-v2/IDepositCallbackReceiver.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";

contract RebalanceHLPv2Service is OwnableUpgradeable, IDepositCallbackReceiver, IRebalanceHLPv2Service {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IVaultStorage public vaultStorage;
  IConfigStorage public configStorage;
  IGmxExchangeRouter public exchangeRouter;
  address public depositVault;
  address public depositHandler; // 0x9Dc4f12Eb2d8405b499FB5B8AF79a5f64aB8a457
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

  event LogSetMinHLPValueLossBPS(uint16 oldValue, uint16 newValue);

  function initialize(
    address _vaultStorage,
    address _configStorage,
    address _exchangeRouter,
    address _depositVault,
    address _depositHandler,
    uint16 _minHLPValueLossBPS
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    vaultStorage = IVaultStorage(_vaultStorage);
    configStorage = IConfigStorage(_configStorage);
    exchangeRouter = IGmxExchangeRouter(_exchangeRouter);
    depositVault = _depositVault;
    depositHandler = _depositHandler;
    minHLPValueLossBPS = _minHLPValueLossBPS;
  }

  function executeDeposits(DepositParams[] calldata depositParams) external onlyWhitelisted {
    for (uint256 i; i < depositParams.length; i++) {
      DepositParams memory depositParam = depositParams[i];
      if (depositParam.longTokenAmount > 0) {
        vaultStorage.pushToken(depositParam.longToken, address(depositVault), depositParam.longTokenAmount);
        vaultStorage.removeHLPLiquidityOnHold(depositParam.longToken, depositParam.longTokenAmount);
        // exchangeRouter.sendTokens(depositParam.longToken, address(depositVault), depositParam.longTokenAmount);
      }

      if (depositParam.shortTokenAmount > 0) {
        vaultStorage.pushToken(depositParam.shortToken, address(depositVault), depositParam.shortTokenAmount);
        vaultStorage.removeHLPLiquidityOnHold(depositParam.shortToken, depositParam.shortTokenAmount);
        // exchangeRouter.sendTokens(depositParam.shortToken, address(depositVault), depositParam.shortTokenAmount);
      }

      IGmxExchangeRouter.CreateDepositParams memory gmxDepositParams;
      gmxDepositParams.receiver = address(this);
      gmxDepositParams.callbackContract = address(this);
      gmxDepositParams.market = depositParam.market;
      gmxDepositParams.initialLongToken = depositParam.longToken;
      gmxDepositParams.initialShortToken = depositParam.shortToken;
      gmxDepositParams.minMarketTokens = depositParam.minMarketTokens;
      gmxDepositParams.executionFee = depositParam.executionFee;
      gmxDepositParams.callbackGasLimit = 50000;

      bytes32 gmxOrderKey = exchangeRouter.createDeposit(address(this), gmxDepositParams);
      depositHistory[gmxOrderKey] = depositParam;
    }
  }

  function afterDepositExecution(
    bytes32 key,
    Deposit.Props memory /* deposit */,
    EventUtils.EventLogData memory eventData
  ) external onlyGmxDepositHandler {
    DepositParams memory depositParam = depositHistory[key];
    if (depositParam.longToken == address(0) && depositParam.shortToken == address(0))
      revert IRebalanceHLPv2Service_KeyNotFound();

    uint256 receivedMarketTokens = eventData.uintItems.items[0].value;
    if (receivedMarketTokens == 0) revert IRebalanceHLPv2Service_ZeroMarketTokenReceived();

    if (depositParam.longTokenAmount > 0) {
      vaultStorage.pullTokenAndClearOnHold(depositParam.longToken, depositParam.longTokenAmount);
    }

    if (depositParam.shortTokenAmount > 0) {
      vaultStorage.pullTokenAndClearOnHold(depositParam.shortToken, depositParam.shortTokenAmount);
    }

    IERC20Upgradeable(depositParam.market).safeTransfer(address(vaultStorage), receivedMarketTokens);
    vaultStorage.pullToken(depositParam.market);

    delete depositHistory[key];
  }

  // @dev called after a deposit cancellation
  // @param key the key of the deposit
  // @param deposit the deposit that was cancelled
  function afterDepositCancellation(
    bytes32 key,
    Deposit.Props memory deposit,
    EventUtils.EventLogData memory eventData
  ) external onlyGmxDepositHandler {}

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

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
