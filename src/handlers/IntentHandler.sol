// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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
contract IntentHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable, IIntentHandler {
  using WordCodec for bytes32;

  IEcoPyth public pyth;
  ConfigStorage public configStorage;
  VaultStorage public vaultStorage;
  TradeOrderHelper public tradeOrderHelper;
  uint256 public executionFeeInUsd;
  address public executionFeeTreasury;
  mapping(bytes32 key => bool executed) executedIntents;
  mapping(address executor => bool isAllow) public intentExecutors; // The allowed addresses to execute intents

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

    pyth = IEcoPyth(_pyth);
    configStorage = ConfigStorage(_configStorage);
    vaultStorage = VaultStorage(_vaultStorage);
    tradeOrderHelper = TradeOrderHelper(_tradeOrderHelper);
    executionFeeInUsd = _executionFeeInUsd;
    executionFeeTreasury = _executionFeeTreasury;
  }

  function execute(ExecuteIntentInputs memory inputs) external {
    if (inputs.accountAndSubAccountIds.length != inputs.cmds.length) revert IntentHandler_BadLength();

    ExecuteIntentVars memory _localVars;

    // Update price to Pyth
    pyth.updatePriceFeeds(inputs.priceData, inputs.publishTimeData, inputs.minPublishTime, inputs.encodedVaas);

    _localVars.cmdsLength = inputs.accountAndSubAccountIds.length;
    _localVars.tpTokens = configStorage.getHlpTokens();

    for (uint256 _i; _i < _localVars.cmdsLength; ) {
      _localVars.mainAccount = address(uint160(inputs.accountAndSubAccountIds[_i].decodeUint(0, 160)));
      _localVars.subAccountId = uint8(inputs.accountAndSubAccountIds[_i].decodeUint(160, 8));
      Command _cmd = Command(inputs.cmds[_i].decodeUint(0, 3));

      if (_cmd == Command.ExecuteTradeOrder) {
        ExecuteTradeOrderVars memory _vars;
        _vars.marketIndex = inputs.cmds[_i].decodeUint(3, 8);
        _vars.sizeDelta = inputs.cmds[_i].decodeInt(11, 54) * 1e22;
        _vars.triggerPrice = inputs.cmds[_i].decodeUint(65, 54) * 1e22;
        _vars.acceptablePrice = inputs.cmds[_i].decodeUint(119, 54) * 1e22;
        _vars.triggerAboveThreshold = inputs.cmds[_i].decodeBool(173);
        _vars.reduceOnly = inputs.cmds[_i].decodeBool(174);
        _vars.tpToken = _localVars.tpTokens[uint256(inputs.cmds[_i].decodeUint(175, 7))];
        _vars.createdTimestamp = inputs.cmds[_i].decodeUint(182, 32);
        _vars.account = _localVars.mainAccount;
        _vars.subAccountId = _localVars.subAccountId;

        bytes32 key = keccak256(abi.encode(inputs.accountAndSubAccountIds[_i], inputs.cmds[_i]));
        if (executedIntents[key]) {
          revert IntentHandler_IntentReplay();
        }

        _validateSignature(inputs.cmds[_i], inputs.signatures[_i], _localVars.mainAccount);
        _executeTradeOrder(_vars);
        _collectExecutionFeeFromCollateral(_localVars.mainAccount, _localVars.subAccountId);

        executedIntents[key] = true;
      }

      unchecked {
        ++_i;
      }
    }
  }

  function _executeTradeOrder(ExecuteTradeOrderVars memory vars) internal {
    // try executing order
    try tradeOrderHelper.execute(vars) {
      // Execution succeeded
    } catch Error(string memory errMsg) {
      _handleOrderFail(vars, bytes(errMsg));
    } catch Panic(uint /*errorCode*/) {
      _handleOrderFail(vars, bytes("Panic occurred while executing trade order"));
    } catch (bytes memory errMsg) {
      _handleOrderFail(vars, errMsg);
    }
  }

  function _collectExecutionFeeFromCollateral(address _primaryAccount, uint8 _subAccountId) internal {
    bytes32[] memory _hlpAssetIds = configStorage.getHlpAssetIds();
    uint256 _len = _hlpAssetIds.length;
    address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
    OracleMiddleware _oracle = OracleMiddleware(configStorage.oracle());

    uint256 _executionFeeToBePaidInUsd = executionFeeInUsd;
    for (uint256 _i; _i < _len; ) {
      ConfigStorage.AssetConfig memory _assetConfig = configStorage.getAssetConfig(_hlpAssetIds[_i]);
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
      vars.account,
      vars.subAccountId,
      vars.marketIndex,
      vars.sizeDelta,
      vars.triggerPrice,
      vars.triggerAboveThreshold,
      vars.reduceOnly,
      vars.tpToken,
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

  function _validateSignature(bytes32 message, bytes memory signature, address signer) internal pure {
    address recoveredSigner = ECDSA.recover(message, signature);
    if (signer != recoveredSigner) revert IntenHandler_BadSignature();
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
