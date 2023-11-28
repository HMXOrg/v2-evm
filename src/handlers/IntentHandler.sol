// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// base
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";

// contracts
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { WordCodec } from "@hmx/libraries/WordCodec.sol";

// interfaces
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";

/// @title IntentHandler
contract IntentHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using WordCodec for bytes32;

  IEcoPyth public pyth;
  ConfigStorage public configStorage;
  VaultStorage public vaultStorage;
  TradeService public tradeService;
  uint256 public executionFeeInUsd;
  address public executionFeeTreasury;
  uint256 public maxOrderAge;

  error IntentHandler_NotEnoughCollateral();
  error IntentHandler_BadLength();
  error IntentHandler_OrderStale();

  enum Command {
    ExecuteTradeOrder
  }

  struct ExecuteTradeOrderVars {
    uint256 marketIndex;
    int256 sizeDelta;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    bool triggerAboveThreshold;
    uint256 executionFee;
    bool reduceOnly;
    address tpToken;
    uint256 createdTimestamp;
    address subAccount;
    bytes32 positionId;
    bool positionIsLong;
    bool isNewPosition;
    bool isMarketOrder;
  }

  function executeIntent(
    bytes32[] calldata _accountAndSubAccountIds,
    bytes32[] calldata _cmds,
    bytes32[] calldata _priceData,
    bytes32[] calldata _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external {
    if (_accountAndSubAccountIds.length != _cmds.length) revert IntentHandler_BadLength();

    // Update price to Pyth
    pyth.updatePriceFeeds(_priceData, _publishTimeData, _minPublishTime, _encodedVaas);

    uint256 _len = _accountAndSubAccountIds.length;
    address[] memory _tpTokens = configStorage.getHlpTokens();

    for (uint256 _i; _i < _len; ) {
      address _mainAccount = address(uint160(_accountAndSubAccountIds[_i].decodeUint(0, 160)));
      uint8 _subAccountId = uint8(_accountAndSubAccountIds[_i].decodeUint(160, 8));
      Command _cmd = Command(_cmds[i].decodeUint(0, 3));

      if (_cmd == Command.ExecuteTradeOrder) {
        ExecuteTradeOrderVars memory _localVars;
        _localVars.marketIndex = _cmds[_i].decodeUint(3, 8);
        _localVars.sizeDelta = _cmds[_i].decodeInt(11, 54) * 1e22;
        _localVars.triggerPrice = _cmds[_i].decodeUint(65, 54) * 1e22;
        _localVars.acceptablePrice = _cmds[_i].decodeUint(119, 54) * 1e22;
        _localVars.triggerAboveThreshold = _cmds[_i].decodeBool(183);
        _localVars.executionFee = _cmds[_i].decodeUint(184, 27) * 1e10;
        _localVars.reduceOnly = _cmds[_i].decodeBool(211);
        _localVars.tpToken = _tpTokens[uint256(_cmds[_i].decodeUint(212, 7))];
        _localVars.createdTimestamp = _cmds[_i].decodeUint(219, 32);
      }

      unchecked {
        ++_i;
      }
    }
  }

  function _executeTradeOrder(ExecuteTradeOrderVars memory _vars) internal {
    bool isMarketOrder = vars.triggerAboveThreshold && vars.triggerPrice == 0;
    if (isMarketOrder && vars.createdTimestamp + maxOrderAge > block.timestamp) {
      revert IntentHandler_OrderStale();
    }
  }

  function tryExecuteTradeOrder(ExecuteTradeOrderVars memory _vars) external {
    // if not in executing state, then revert
    if (msg.sender != address(this)) revert IntentHandler_Unauthorized();

    TradeService _tradeService = TradeService(tradeService);

    // Execute the order
    if (vars.order.reduceOnly) {
      bool isDecreaseShort = (vars.sizeDelta > 0 && _existingPosition.positionSizeE30 < 0);
      bool isDecreaseLong = (vars.sizeDelta < 0 && _existingPosition.positionSizeE30 > 0);
      bool isClosePosition = !vars.isNewPosition && (isDecreaseShort || isDecreaseLong);
      if (isClosePosition) {
        _tradeService.decreasePosition({
          _account: vars.order.account,
          _subAccountId: vars.order.subAccountId,
          _marketIndex: vars.order.marketIndex,
          _positionSizeE30ToDecrease: HMXLib.min(
            HMXLib.abs(vars.sizeDelta),
            HMXLib.abs(_existingPosition.positionSizeE30)
          ),
          _tpToken: vars.order.tpToken,
          _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
        });
      } else {
        // Do nothing if the size delta is wrong for reduce-only
      }
    } else {
      if (vars.sizeDelta > 0) {
        // BUY
        if (vars.isNewPosition || vars.positionIsLong) {
          // New position and Long position
          // just increase position when BUY
          _tradeService.increasePosition({
            _primaryAccount: vars.order.account,
            _subAccountId: vars.order.subAccountId,
            _marketIndex: vars.order.marketIndex,
            _sizeDelta: vars.sizeDelta,
            _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
          });
        } else {
          bool _flipSide = vars.sizeDelta > (-_existingPosition.positionSizeE30);
          if (_flipSide) {
            // Flip the position
            // Fully close Short position
            _tradeService.decreasePosition({
              _account: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _positionSizeE30ToDecrease: uint256(-_existingPosition.positionSizeE30),
              _tpToken: vars.order.tpToken,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
            // Flip it to Long position
            _tradeService.increasePosition({
              _primaryAccount: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _sizeDelta: vars.sizeDelta + _existingPosition.positionSizeE30,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
          } else {
            // Not flip
            _tradeService.decreasePosition({
              _account: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _positionSizeE30ToDecrease: uint256(vars.sizeDelta),
              _tpToken: vars.order.tpToken,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
          }
        }
      } else if (vars.sizeDelta < 0) {
        // SELL
        if (vars.isNewPosition || !vars.positionIsLong) {
          // New position and Short position
          // just increase position when SELL
          _tradeService.increasePosition({
            _primaryAccount: vars.order.account,
            _subAccountId: vars.order.subAccountId,
            _marketIndex: vars.order.marketIndex,
            _sizeDelta: vars.sizeDelta,
            _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
          });
        } else if (vars.positionIsLong) {
          bool _flipSide = (-vars.sizeDelta) > _existingPosition.positionSizeE30;
          if (_flipSide) {
            // Flip the position
            // Fully close Long position
            _tradeService.decreasePosition({
              _account: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _positionSizeE30ToDecrease: uint256(_existingPosition.positionSizeE30),
              _tpToken: vars.order.tpToken,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
            // Flip it to Short position
            _tradeService.increasePosition({
              _primaryAccount: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _sizeDelta: vars.sizeDelta + _existingPosition.positionSizeE30,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
          } else {
            // Not flip
            _tradeService.decreasePosition({
              _account: vars.order.account,
              _subAccountId: vars.order.subAccountId,
              _marketIndex: vars.order.marketIndex,
              _positionSizeE30ToDecrease: uint256(-vars.sizeDelta),
              _tpToken: vars.order.tpToken,
              _limitPriceE30: _isGuaranteeLimitPrice ? vars.order.triggerPrice : 0
            });
          }
        }
      }
    }
  }

  function collectExecutionFeeFromCollateral(address _primaryAccount, uint8 _subAccountId) internal {
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
}
