// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";

contract TradeService is ITradeService {
  // events
  event LogDecreasePosition(
    bytes32 indexed _positionId,
    uint256 _decreasedSize
  );

  // state
  address public perpStorage;
  address public vaultStorage;
  address public configStorage;
  address public calculator;
  address public oracle;

  constructor(
    address _perpStorage,
    address _vaultStorage,
    address _configStorage,
    address _calculator,
    address _oracle
  ) {
    // todo: sanity check
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = _calculator;
    oracle = _oracle;
  }

  // todo: rewrite description
  /// @notice decrease trader position
  /// @param _account - address
  /// @param _subAccountId - address
  /// @param _marketIndex - market index
  /// @param _positionSizeE30ToDecrease - position size to decrease
  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease
  ) external {
    // prepare
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigById(_marketIndex);

    address _subAccount = _getSubAccount(_account, _subAccountId);
    bytes32 _positionId = _getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_positionId);

    // if position size is 0 means this position is already closed
    int256 _currentPositionSizeE30 = _position.positionSizeE30;
    if (_currentPositionSizeE30 == 0) {
      revert ITradeService_PositionAlreadyClosed();
    }

    bool isLongPosition = _currentPositionSizeE30 > 0;

    uint256 _priceE30;
    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;
      (_priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(oracle)
        .getLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          !isLongPosition, // isMax parameter, if LONG position we use MinPrice, and MaxPrice for SHORT
          _marketConfig.priceConfidentThreshold
        );

      // =========================================
      // | ---------- pre validation ----------- |
      // =========================================
      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is 1, means that oracle couldn't get price from pyth
      if (_marketStatus == 1) revert ITradeService_MarketIsClosed();

      // check price stale for 30 seconds
      // todo: do it as config, and fix related testcase
      if (block.timestamp - _lastPriceUpdated > 30)
        revert ITradeService_PriceStale();
    }

    uint256 _absolutePositionSizeE30 = uint256(
      isLongPosition ? _currentPositionSizeE30 : -_currentPositionSizeE30
    );
    {
      // position size to decrease is greater then position size, should be revert
      if (_positionSizeE30ToDecrease > _absolutePositionSizeE30) {
        revert ITradeService_DecreaseTooHighPositionSize();
      }

      // check sub account is healty
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr) {
        revert ITradeService_SubAccountEquityIsUnderMMR();
      }
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

    {
      uint256 _imr = (_newPositivePositionSize *
        _marketConfig.initialMarginFraction) / 1e18;

      _position = IPerpStorage(perpStorage).updatePositionById(
        _positionId,
        isLongPosition
          ? int256(_newPositivePositionSize)
          : -int256(_newPositivePositionSize), // todo: optimized
        (_imr * _marketConfig.maxProfitRate) / 1e18, // _newReserveValueE30
        _newPositivePositionSize == 0 ? 0 : _position.avgEntryPriceE30 // _newAvgPriceE30
      );

      // if position size > 0, then the position is Long position
      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
        .getGlobalMarketById(_marketIndex);

      uint256 _changedOpenInterest = (_positionSizeE30ToDecrease * 1e30) /
        _priceE30;

      if (isLongPosition) {
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.longAvgPrice, // todo: recalculate arg price
          _globalMarket.longOpenInterest - _changedOpenInterest
        );
      } else {
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketIndex,
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
      // check position is too tiny
      // todo: now validate this at 1 USD, design where to keep this config
      //       due to we has problem stack too deep in MarketConfig now
      if (_newPositivePositionSize > 0 && _newPositivePositionSize < 1e30) {
        revert ITradeService_TooTinyPosition();
      }

      // check sub account is healty
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr) {
        revert ITradeService_SubAccountEquityIsUnderMMR();
      }
    }

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
    uint256 _marketIndex
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketIndex));
  }
}
