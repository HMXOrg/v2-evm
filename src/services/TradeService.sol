// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// openzepline
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";

contract TradeService is ITradeService {
  using SafeCast for int256;
  using SafeCast for uint256;

  // events
  event LogDecreasePosition(
    bytes32 indexed _positionId,
    uint256 _decreasedSize
  );

  // state
  address perpStorage;
  address vaultStorage;
  address configStorage;
  address calculator;

  constructor(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _calculator
  ) {
    // todo: sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = _calculator;
  }

  // todo: rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketId - market id
  /// @param _positionSizeE30ToDecrease - position size to decrease
  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketId,
    uint256 _positionSizeE30ToDecrease
  ) external {
    // prepare
    // todo: integrate with oracle
    uint256 _currentPrice = 1e30;

    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigById(_marketId);

    address _subAccount = _getSubAccount(_account, _subAccountId);
    bytes32 _positionId = _getPositionId(_subAccount, _marketId);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_positionId);

    // =========================================
    // | ---------- pre validation ----------- |
    // =========================================
    // todo: check market status
    bool isLongPosition = _position.positionSizeE30 > 0;
    uint256 _absolutePositionSizeE30 = (
      isLongPosition ? _position.positionSizeE30 : -_position.positionSizeE30
    ).toUint256();

    // if position size is 0 means this position is already closed
    if (_absolutePositionSizeE30 == 0) {
      revert ITradeService_PositionAlreadyClosed();
    }

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > _absolutePositionSizeE30) {
      revert ITradeService_DecreaseTooHighPositionSize();
    }

    // check sub account is healty
    uint256 _subAccountEquity = ICalculator(calculator).getEquity(_subAccount);
    // maintenance margin requirement (MMR) = position size * maintenance margin fraction
    // note: maintenanceMarginFraction is 1e18
    uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

    // if sub account equity < MMR, then trader couln't decrease position
    if (_subAccountEquity < _mmr) {
      revert ITradeService_SubAccountEquityIsUnderMMR();
    }

    // todo: update funding & borrowing fee rate
    // todo: calculate trading, borrowing and funding fee
    // todo: collect fee
    // todo: calculate USD out

    // =========================================
    // | ------ update perp storage ---------- |
    // =========================================
    uint256 _newPositivePositionSize = _absolutePositionSizeE30 -
      _positionSizeE30ToDecrease;

    _position = IPerpStorage(perpStorage).updatePositionById(
      _positionId,
      isLongPosition
        ? _newPositivePositionSize.toInt256()
        : -(_newPositivePositionSize.toInt256()), // todo: optimized
      (_newPositivePositionSize * _marketConfig.maxProfitRate) / 1e18, // _newReserveValueE30
      _newPositivePositionSize == 0 ? 0 : _position.avgEntryPriceE30 // _newAvgPriceE30
    );

    {
      // if position size > 0, then the position is Long position
      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
        .getGlobalMarketById(_marketId);

      uint256 _changedOpenInterest = (_positionSizeE30ToDecrease * 1e30) /
        _currentPrice;

      if (isLongPosition) {
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketId,
          _globalMarket.longPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.longAvgPrice, // todo: recalculate arg price
          _globalMarket.longOpenInterest - _changedOpenInterest
        );
      } else {
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketId,
          _globalMarket.shortPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.shortAvgPrice, // todo: recalculate arg price
          _globalMarket.shortOpenInterest - _changedOpenInterest
        );
      }
    }

    // =========================================
    // | ------- settlement position --------- |
    // =========================================
    // todo: settle profit & loss

    // =========================================
    // | --------- post validation ----------- |
    // =========================================
    {
      // check sub account is healty
      _subAccountEquity = ICalculator(calculator).getEquity(_subAccount);
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr) {
        revert ITradeService_SubAccountEquityIsUnderMMR();
      }

      // check position is too tiny
      // todo: now validate this at 1 USD, design where to keep this config
      //       due to we has problem stack too deep in MarketConfig now
      if (_newPositivePositionSize < 1e30) {
        revert ITradeService_TooTinyPosition();
      }
    }

    // todo: bad debt

    emit LogDecreasePosition(_positionId, _positionSizeE30ToDecrease);
  }

  // todo: add description
  function _getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address) {
    if (_subAccountId > 255) revert();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  // todo: add description
  function _getPositionId(
    address _account,
    uint256 _marketId
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketId));
  }
}
