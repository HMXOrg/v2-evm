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
  // struct
  struct DecreasePositionVars {
    uint256 absPositionSizeE30;
    uint256 priceE30;
    int256 currentPositionSizeE30;
    bool isLongPosition;
  }

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

    // init vars
    DecreasePositionVars memory vars = DecreasePositionVars({
      absPositionSizeE30: 0,
      priceE30: 0,
      currentPositionSizeE30: 0,
      isLongPosition: false
    });

    // =========================================
    // | ---------- pre validation ----------- |
    // =========================================

    // if position size is 0 means this position is already closed
    vars.currentPositionSizeE30 = _position.positionSizeE30;
    if (vars.currentPositionSizeE30 == 0)
      revert ITradeService_PositionAlreadyClosed();

    vars.isLongPosition = vars.currentPositionSizeE30 > 0;

    // convert position size to be uint256
    vars.absPositionSizeE30 = uint256(
      vars.isLongPosition
        ? vars.currentPositionSizeE30
        : -vars.currentPositionSizeE30
    );

    // position size to decrease is greater then position size, should be revert
    if (_positionSizeE30ToDecrease > vars.absPositionSizeE30)
      revert ITradeService_DecreaseTooHighPositionSize();

    {
      uint256 _lastPriceUpdated;
      uint8 _marketStatus;

      (vars.priceE30, _lastPriceUpdated, _marketStatus) = IOracleMiddleware(
        oracle
      ).getLatestPriceWithMarketStatus(
          _marketConfig.assetId,
          !vars.isLongPosition, // if current position is SHORT position, then we use max price
          _marketConfig.priceConfidentThreshold
        );

      // Market active represent the market is still listed on our protocol
      if (!_marketConfig.active) revert ITradeService_MarketIsDelisted();

      // if market status is 1, means that oracle couldn't get price from pyth
      if (_marketStatus == 1) revert ITradeService_MarketIsClosed();

      // check price stale for 30 seconds
      // todo: do it as config, and fix related testcase
      if (block.timestamp - _lastPriceUpdated > 30)
        revert ITradeService_PriceStale();

      // check sub account is healty
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr)
        revert ITradeService_SubAccountEquityIsUnderMMR();
    }

    // todo: update funding & borrowing fee rate
    // todo: calculate trading, borrowing and funding fee
    // todo: collect fee

    // =========================================
    // | ------ update perp storage ---------- |
    // =========================================
    uint256 _newAbsPositionSizeE30 = vars.absPositionSizeE30 -
      _positionSizeE30ToDecrease;

    // check position is too tiny
    // todo: now validate this at 1 USD, design where to keep this config
    //       due to we has problem stack too deep in MarketConfig now
    if (_newAbsPositionSizeE30 > 0 && _newAbsPositionSizeE30 < 1e30)
      revert ITradeService_TooTinyPosition();

    {
      uint256 _openInterestDelta = (_position.openInterest *
        _positionSizeE30ToDecrease) / vars.absPositionSizeE30;

      // update position info
      IPerpStorage(perpStorage).updatePositionById(
        _positionId,
        vars.isLongPosition
          ? int256(_newAbsPositionSizeE30)
          : -int256(_newAbsPositionSizeE30), // todo: optimized
        // new position size * IMF * max profit rate
        (((_newAbsPositionSizeE30 * _marketConfig.initialMarginFraction) /
          1e18) * _marketConfig.maxProfitRate) / 1e18,
        _position.avgEntryPriceE30,
        _position.openInterest - _openInterestDelta
      );

      IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
        .getGlobalMarketByIndex(_marketIndex);

      if (vars.isLongPosition) {
        IPerpStorage(perpStorage).updateGlobalLongMarketById(
          _marketIndex,
          _globalMarket.longPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.longAvgPrice, // todo: recalculate arg price
          _globalMarket.longOpenInterest - _openInterestDelta
        );
      } else {
        IPerpStorage(perpStorage).updateGlobalShortMarketById(
          _marketIndex,
          _globalMarket.shortPositionSize - _positionSizeE30ToDecrease,
          _globalMarket.shortAvgPrice, // todo: recalculate arg price
          _globalMarket.shortOpenInterest - _openInterestDelta
        );
      }
      IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage)
        .getGlobalState();

      // update global storage
      // to calculate new global reserve = current global reserve - reserve delta (position reserve * (position size delta / current position size))
      IPerpStorage(perpStorage).updateGlobalState(
        _globalState.reserveValueE30 -
          ((_position.reserveValueE30 * _positionSizeE30ToDecrease) /
            vars.absPositionSizeE30)
      );
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
      uint256 _subAccountEquity = ICalculator(calculator).getEquity(
        _subAccount
      );
      // maintenance margin requirement (MMR) = position size * maintenance margin fraction
      // note: maintenanceMarginFraction is 1e18
      uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

      // if sub account equity < MMR, then trader couln't decrease position
      if (_subAccountEquity < _mmr)
        revert ITradeService_SubAccountEquityIsUnderMMR();
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
