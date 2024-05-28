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
import { GasService } from "@hmx/services/GasService.sol";

// interfaces
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IIntentHandler } from "@hmx/handlers/interfaces/IIntentHandler.sol";
import { ITradeOrderHelper } from "@hmx/helpers/interfaces/ITradeOrderHelper.sol";

/// @title IntentHandler
contract IntentHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable, IIntentHandler {
  using WordCodec for bytes32;

  IEcoPyth public pyth;
  ConfigStorage public configStorage;
  TradeOrderHelper public tradeOrderHelper;
  GasService public gasService;
  mapping(bytes32 key => bool executed) executedIntents;
  mapping(address executor => bool isAllow) public intentExecutors; // The allowed addresses to execute intents
  mapping(address mainAccount => address tradingWallet) public delegations;

  modifier onlyIntentExecutors() {
    if (!intentExecutors[msg.sender]) revert IntentHandler_Unauthorized();
    _;
  }

  function initialize(
    address _pyth,
    address _configStorage,
    address _tradeOrderHelper,
    address _gasService
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    EIP712Upgradeable.__EIP712_init("IntentHander", "1.0.0");

    pyth = IEcoPyth(_pyth);
    configStorage = ConfigStorage(_configStorage);
    tradeOrderHelper = TradeOrderHelper(_tradeOrderHelper);
    gasService = GasService(_gasService);
  }

  function setDelegate(address _delegate) external {
    delegations[msg.sender] = _delegate;
    emit LogSetDelegate(msg.sender, _delegate);
  }

  function execute(ExecuteIntentInputs memory inputs) external onlyIntentExecutors {
    if (inputs.accountAndSubAccountIds.length != inputs.cmds.length) revert IntentHandler_BadLength();

    ExecuteIntentVars memory _localVars;
    ExecuteTradeOrderVars memory _vars;

    // Update price to Pyth
    pyth.updatePriceFeeds(inputs.priceData, inputs.publishTimeData, inputs.minPublishTime, inputs.encodedVaas);

    _localVars.cmdsLength = inputs.accountAndSubAccountIds.length;
    _localVars.tpTokens = configStorage.getHlpTokens();
    _localVars.gasBefore;

    for (uint256 _i; _i < _localVars.cmdsLength; ) {
      _localVars.gasBefore = gasleft();
      _localVars.mainAccount = address(uint160(inputs.accountAndSubAccountIds[_i].decodeUint(0, 160)));
      _localVars.subAccountId = uint8(inputs.accountAndSubAccountIds[_i].decodeUint(160, 8));
      _localVars.cmd = Command(inputs.cmds[_i].decodeUint(0, 3));

      if (_localVars.cmd == Command.ExecuteTradeOrder) {
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

        _localVars.key = keccak256(abi.encode(inputs.accountAndSubAccountIds[_i], inputs.cmds[_i]));
        if (executedIntents[_localVars.key]) {
          emit LogIntentReplay(_localVars.key);

          unchecked {
            ++_i;
          }
          continue;
        }

        if (!_validateSignature(_vars.order, inputs.signatures[_i], _localVars.mainAccount)) {
          emit LogBadSignature(_localVars.key);
          unchecked {
            ++_i;
          }
          continue;
        }

        // Pre-validate order here and if fail, the order will be canceled and marked as executed.
        bool _isPreValidateSuccess = _prevalidateExecuteTradeOrder(_vars);
        if (!_isPreValidateSuccess) {
          executedIntents[_localVars.key] = true;

          unchecked {
            ++_i;
          }
          continue;
        }
        (
          _localVars.isSuccess,
          _localVars.oraclePrice,
          _localVars.executedPrice,
          _localVars.isFullClose
        ) = _executeTradeOrder(_vars, _localVars.key);

        // If the trade order is executed successfully, record the order as executed
        if (_localVars.isSuccess) {
          executedIntents[_localVars.key] = true;
          emit LogExecuteTradeOrderSuccess(
            _vars.order.account,
            _vars.order.subAccountId,
            _vars.order.marketIndex,
            _vars.order.sizeDelta,
            _vars.order.triggerPrice,
            _vars.order.triggerAboveThreshold,
            _vars.order.reduceOnly,
            _vars.order.tpToken,
            _localVars.oraclePrice,
            _localVars.executedPrice,
            _localVars.isFullClose,
            _localVars.key
          );
        } else if (!_localVars.isSuccess && _vars.order.triggerPrice == 0) {
          executedIntents[_localVars.key] = true;
        }
      }

      try
        gasService.collectExecutionFeeFromCollateral(
          _localVars.mainAccount,
          _localVars.subAccountId,
          _vars.order.marketIndex,
          HMXLib.abs(_vars.order.sizeDelta),
          _localVars.gasBefore
        )
      {} catch {
        emit LogCollectExecutionFeeFailed(_localVars.key);
        unchecked {
          ++_i;
        }
        continue;
      }

      unchecked {
        ++_i;
      }
    }
  }

  function _prevalidateExecuteTradeOrder(ExecuteTradeOrderVars memory vars) internal view returns (bool isSuccess) {
    (isSuccess, ) = tradeOrderHelper.preValidate(
      vars.order.account,
      vars.order.subAccountId,
      vars.order.marketIndex,
      vars.order.reduceOnly,
      vars.order.sizeDelta,
      vars.order.expiryTimestamp
    );
  }

  function _executeTradeOrder(
    ExecuteTradeOrderVars memory vars,
    bytes32 key
  ) internal returns (bool isSuccess, uint256 oraclePrice, uint256 executedPrice, bool isFullClose) {
    // try executing order
    try tradeOrderHelper.execute(vars) returns (uint256 _oraclePrice, uint256 _executedPrice, bool _isFullClose) {
      // Execution succeeded
      return (true, _oraclePrice, _executedPrice, _isFullClose);
    } catch Error(string memory errMsg) {
      _handleOrderFail(vars, bytes(errMsg), key);
    } catch Panic(uint /*errorCode*/) {
      _handleOrderFail(vars, bytes("Panic occurred while executing trade order"), key);
    } catch (bytes memory errMsg) {
      _handleOrderFail(vars, errMsg, key);
    }
    return (false, 0, 0, false);
  }

  function _handleOrderFail(ExecuteTradeOrderVars memory vars, bytes memory errMsg, bytes32 key) internal {
    emit LogExecuteTradeOrderFail(
      vars.order.account,
      vars.order.subAccountId,
      vars.order.marketIndex,
      vars.order.sizeDelta,
      vars.order.triggerPrice,
      vars.order.triggerAboveThreshold,
      vars.order.reduceOnly,
      vars.order.tpToken,
      errMsg,
      key
    );
  }

  function _validateSignature(
    IIntentHandler.TradeOrder memory _tradeOrder,
    bytes memory _signature,
    address _signer
  ) internal view returns (bool) {
    address _recoveredSigner = ECDSAUpgradeable.recover(getDigest(_tradeOrder), _signature);
    address _tradingWallet = delegations[_signer];
    if (_signer != _recoveredSigner && _tradingWallet != _recoveredSigner) {
      return false;
    }
    return true;
  }

  function getDigest(IIntentHandler.TradeOrder memory _tradeOrder) public view returns (bytes32 _digest) {
    _digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256(
            "TradeOrder(uint256 marketIndex,int256 sizeDelta,uint256 triggerPrice,uint256 acceptablePrice,bool triggerAboveThreshold,bool reduceOnly,address tpToken,uint256 createdTimestamp,uint256 expiryTimestamp,address account,uint8 subAccountId)"
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

  function setTradeOrderHelper(address _newTradeOrderHelper) external nonReentrant onlyOwner {
    emit LogSetTradeOrderHelper(address(tradeOrderHelper), _newTradeOrderHelper);
    tradeOrderHelper = TradeOrderHelper(_newTradeOrderHelper);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
