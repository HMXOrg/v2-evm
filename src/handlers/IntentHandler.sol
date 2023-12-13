// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ECDSAUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";

// contracts
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { WordCodec } from "@hmx/libraries/WordCodec.sol";
import { TradeOrderHelper } from "@hmx/helpers/TradeOrderHelper.sol";

// interfaces
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IIntentHandler } from "@hmx/handlers/interfaces/IIntentHandler.sol";

/// @title IntentHandler
contract IntentHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable, IIntentHandler {
  using WordCodec for bytes32;

  IEcoPyth public pyth;
  ConfigStorage public configStorage;
  VaultStorage public vaultStorage;
  TradeOrderHelper public tradeOrderHelper;
  uint256 public executionFeeInUsd;
  address public executionFeeTreasury;
  mapping(bytes32 key => bool executed) executedIntents;
  mapping(address executor => bool isAllow) public intentExecutors; // The allowed addresses to execute intents

  modifier onlyIntentExecutors() {
    if (!intentExecutors[msg.sender]) revert IntentHandler_Unauthorized();
    _;
  }

  function initialize(
    address _pyth,
    address _configStorage,
    address _vaultStorage,
    address _tradeOrderHelper,
    uint256 _executionFeeInUsd,
    address _executionFeeTreasury
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    EIP712Upgradeable.__EIP712_init("IntentHander", "1.0.0");

    pyth = IEcoPyth(_pyth);
    configStorage = ConfigStorage(_configStorage);
    vaultStorage = VaultStorage(_vaultStorage);
    tradeOrderHelper = TradeOrderHelper(_tradeOrderHelper);
    executionFeeInUsd = _executionFeeInUsd;
    executionFeeTreasury = _executionFeeTreasury;
  }

  function execute(ExecuteIntentInputs memory inputs) external onlyIntentExecutors {
    if (inputs.accountAndSubAccountIds.length != inputs.cmds.length) revert IntentHandler_BadLength();

    ExecuteIntentVars memory _localVars;
    Command _cmd;
    ExecuteTradeOrderVars memory _vars;
    bytes32 key;

    // Update price to Pyth
    pyth.updatePriceFeeds(inputs.priceData, inputs.publishTimeData, inputs.minPublishTime, inputs.encodedVaas);

    _localVars.cmdsLength = inputs.accountAndSubAccountIds.length;
    _localVars.tpTokens = configStorage.getHlpTokens();

    for (uint256 _i; _i < _localVars.cmdsLength; ) {
      _localVars.mainAccount = address(uint160(inputs.accountAndSubAccountIds[_i].decodeUint(0, 160)));
      _localVars.subAccountId = uint8(inputs.accountAndSubAccountIds[_i].decodeUint(160, 8));
      _cmd = Command(inputs.cmds[_i].decodeUint(0, 3));

      if (_cmd == Command.ExecuteTradeOrder) {
        _vars.order.marketIndex = inputs.cmds[_i].decodeUint(3, 8);
        _vars.order.sizeDelta = inputs.cmds[_i].decodeInt(11, 54) * 1e22;
        _vars.order.triggerPrice = inputs.cmds[_i].decodeUint(65, 54) * 1e22;
        _vars.order.acceptablePrice = inputs.cmds[_i].decodeUint(119, 54) * 1e22;
        _vars.order.triggerAboveThreshold = inputs.cmds[_i].decodeBool(173);
        _vars.order.reduceOnly = inputs.cmds[_i].decodeBool(174);
        _vars.order.tpToken = _localVars.tpTokens[uint256(inputs.cmds[_i].decodeUint(175, 7))];
        _vars.order.createdTimestamp = inputs.cmds[_i].decodeUint(182, 32);
        _vars.order.expiryTimestamp = inputs.cmds[_i].decodeUint(214, 32);
        _vars.order.account = _localVars.mainAccount;
        _vars.order.subAccountId = _localVars.subAccountId;

        key = keccak256(abi.encode(inputs.accountAndSubAccountIds[_i], inputs.cmds[_i]));
        if (executedIntents[key]) {
          revert IntentHandler_IntentReplay();
        }

        _validateSignature(_vars.order, inputs.signatures[_i], _localVars.mainAccount);
        _collectExecutionFeeFromCollateral(_localVars.mainAccount, _localVars.subAccountId);
        bool _isSuccess = _executeTradeOrder(_vars);

        // If the trade order is executed successfully, record the order as executed
        if (_isSuccess) executedIntents[key] = true;
      }

      unchecked {
        ++_i;
      }
    }
  }

  function _executeTradeOrder(ExecuteTradeOrderVars memory vars) internal returns (bool isSuccess) {
    // try executing order
    try tradeOrderHelper.execute(vars) {
      // Execution succeeded
      return true;
    } catch Error(string memory errMsg) {
      _handleOrderFail(vars, bytes(errMsg));
    } catch Panic(uint /*errorCode*/) {
      _handleOrderFail(vars, bytes("Panic occurred while executing trade order"));
    } catch (bytes memory errMsg) {
      _handleOrderFail(vars, errMsg);
    }
    return false;
  }

  function _collectExecutionFeeFromCollateral(address _primaryAccount, uint8 _subAccountId) internal {
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    address[] memory _traderTokens = vaultStorage.getTraderTokens(_subAccount);
    uint256 _len = _traderTokens.length;
    OracleMiddleware _oracle = OracleMiddleware(configStorage.oracle());

    uint256 _executionFeeToBePaidInUsd = executionFeeInUsd;
    for (uint256 _i; _i < _len; ) {
      bytes32 _assetId = configStorage.tokenAssetIds(_traderTokens[_i]);
      ConfigStorage.AssetConfig memory _assetConfig = configStorage.getAssetConfig(_assetId);
      address _token = _assetConfig.tokenAddress;
      uint256 _userBalance = vaultStorage.traderBalances(_subAccount, _token);

      if (_userBalance > 0) {
        (uint256 _tokenPrice, ) = _oracle.getLatestPrice(_assetConfig.assetId, false);
        uint8 _tokenDecimal = _assetConfig.decimals;

        (uint256 _payAmount, uint256 _payValue) = _getPayAmount(
          _userBalance,
          _executionFeeToBePaidInUsd,
          _tokenPrice,
          _tokenDecimal
        );

        vaultStorage.decreaseTraderBalance(_subAccount, _token, _payAmount);
        vaultStorage.increaseTraderBalance(executionFeeTreasury, _token, _payAmount);

        _executionFeeToBePaidInUsd -= _payValue;

        if (_executionFeeToBePaidInUsd == 0) {
          break;
        }
      }

      unchecked {
        ++_i;
      }
    }

    if (_executionFeeToBePaidInUsd > 0) {
      revert IntentHandler_NotEnoughCollateral();
    }
  }

  function _handleOrderFail(ExecuteTradeOrderVars memory vars, bytes memory errMsg) internal {
    emit LogExecuteTradeOrderFail(
      vars.order.account,
      vars.order.subAccountId,
      vars.order.marketIndex,
      vars.order.sizeDelta,
      vars.order.triggerPrice,
      vars.order.triggerAboveThreshold,
      vars.order.reduceOnly,
      vars.order.tpToken,
      errMsg
    );
  }

  function _getPayAmount(
    uint256 _payerBalance,
    uint256 _valueE30,
    uint256 _tokenPrice,
    uint8 _tokenDecimal
  ) internal pure returns (uint256 _payAmount, uint256 _payValueE30) {
    uint256 _feeAmount = (_valueE30 * (10 ** _tokenDecimal)) / _tokenPrice;

    if (_payerBalance > _feeAmount) {
      // _payerBalance can cover the rest of the fee
      return (_feeAmount, _valueE30);
    } else {
      // _payerBalance cannot cover the rest of the fee, just take the amount the trader have
      uint256 _payerBalanceValue = (_payerBalance * _tokenPrice) / (10 ** _tokenDecimal);
      return (_payerBalance, _payerBalanceValue);
    }
  }

  function _validateSignature(
    IIntentHandler.TradeOrder memory _tradeOrder,
    bytes memory _signature,
    address _signer
  ) internal view {
    address _recoveredSigner = ECDSAUpgradeable.recover(getDigest(_tradeOrder), _signature);
    if (_signer != _recoveredSigner) revert IntenHandler_BadSignature();
  }

  function getDigest(IIntentHandler.TradeOrder memory _tradeOrder) public view returns (bytes32 _digest) {
    _digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256(
            "TradeOrder(uint256 marketIndex, int256 sizeDelta, uint256 triggerPrice, uint256 acceptablePrice, bool triggerAboveThreshold, bool reduceOnly, address tpToken, uint256 createdTimestamp, uint256 expiryTimestamp, address account, uint8 subAccountId)"
          ),
          _tradeOrder.marketIndex,
          _tradeOrder.sizeDelta,
          _tradeOrder.triggerPrice,
          _tradeOrder.acceptablePrice,
          _tradeOrder.triggerAboveThreshold,
          _tradeOrder.reduceOnly,
          _tradeOrder.tpToken,
          _tradeOrder.createdTimestamp,
          _tradeOrder.expiryTimestamp,
          _tradeOrder.account,
          _tradeOrder.subAccountId
        )
      )
    );
  }

  /// @notice setIntentExecutor
  /// @param _executor address who will be executor
  /// @param _isAllow flag to allow to execute
  function setIntentExecutor(address _executor, bool _isAllow) external nonReentrant onlyOwner {
    if (_executor == address(0)) revert IntentHandler_InvalidAddress();
    intentExecutors[_executor] = _isAllow;
    emit LogSetIntentExecutor(_executor, _isAllow);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
