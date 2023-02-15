// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ITradeService } from "./interfaces/ITradeService.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";

import { Math } from "../utils/Math.sol";

contract TradeService is ITradeService {
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
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
    configStorage = _configStorage;
    calculator = _calculator;
  }

  error BadSubAccountId();

  error InvalidAveragePrice();
  error BadPositionSize();
  error InsufficientLiquidity();
  error InsufficientFreeCollateral();

  // error SubAccountFreeCollateralIsUnderIMR();

  error ITradeService_SubAccountEquityIsUnderMMR();

  function increasePosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external {
    address _subAccount = getSubAccount(_primaryAccount, _subAccountId);
    bytes32 _posId = getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_posId);

    uint256 _price = 21700 * 1e30;
    if (_position.sizeE30 == 0) {
      _position.avgPriceE30 = _price;
    }

    if (_position.sizeE30 != 0 && _sizeDelta != 0) {
      _position.avgPriceE30 = getPositionNextAveragePrice(
        _marketIndex,
        _position.sizeE30,
        _sizeDelta,
        _position.avgPriceE30,
        _price
      );
    }

    // collect trading fee
    // collect borrowing fee
    // update borrowing rate
    // collect funding fee
    // update funding rate

    _position.sizeE30 += _sizeDelta;
    if (_position.sizeE30 == 0) revert BadPositionSize();
    uint256 _absSizeDelta = Math.abs(_sizeDelta);

    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigs(_marketIndex);

    uint256 _imr = (_absSizeDelta * _marketConfig.initialMarginFraction) / 1e18;
    uint256 subAccountFreeCollateral = ICalculator(calculator)
      .getFreeCollateral(_subAccount);

    if (subAccountFreeCollateral < _imr) revert InsufficientFreeCollateral();

    uint256 _maxReserve = (_imr * _marketConfig.maxProfitRate) / 1e18;
    increaseReserved(_maxReserve);

    IPerpStorage(perpStorage).savePosition(_posId, _position);

    // // check liquidate
    // {
    //   // check sub account is healty
    //   uint256 _subAccountEquity = ICalculator(calculator).getEquity(
    //     _subAccount
    //   );
    //   // maintenance margin requirement (MMR) = position size * maintenance margin fraction
    //   // note: maintenanceMarginFraction is 1e18
    //   uint256 _mmr = ICalculator(calculator).getMMR(_subAccount);

    //   // if sub account equity < MMR, then trader couln't decrease position
    //   if (_subAccountEquity < _mmr) {
    //     revert ITradeService_SubAccountEquityIsUnderMMR();
    //   }
    // }

    bool isLong = _sizeDelta > 0;

    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
      .getGlobalMarketById(_marketIndex);

    uint256 _changedOpenInterest = (_absSizeDelta * 1e30) / _price;

    if (isLong) {
      IPerpStorage(perpStorage).updateGlobalLongMarketById(
        _marketIndex,
        _globalMarket.longPositionSize + _absSizeDelta,
        _globalMarket.longAvgPrice, // todo: recalculate arg price
        _globalMarket.longOpenInterest + _changedOpenInterest
      );
    } else {
      IPerpStorage(perpStorage).updateGlobalShortMarketById(
        _marketIndex,
        _globalMarket.shortPositionSize + _absSizeDelta,
        _globalMarket.shortAvgPrice, // todo: recalculate arg price
        _globalMarket.shortOpenInterest + _changedOpenInterest
      );
    }
  }

  function getPositionId(
    address _account,
    uint256 _marketId
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_account, _marketId));
  }

  function getSubAccount(
    address _primary,
    uint256 _subAccountId
  ) internal pure returns (address) {
    if (_subAccountId > 255) revert BadSubAccountId();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  function getPositionNextAveragePrice(
    uint256 marketIndex,
    int256 size,
    int256 sizeDelta,
    uint256 averagePrice,
    uint256 nextPrice
  ) internal pure returns (uint256) {
    (bool isProfit, uint256 delta) = getDelta(marketIndex, size, averagePrice);
    uint256 nextSize = Math.abs(size + sizeDelta);
    // uint256 divisor = Math.abs(isProfit ? nextSize + delta : nextSize - delta);
    uint256 divisor;
    if (size > 0) {
      divisor = isProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = isProfit ? nextSize - delta : nextSize + delta;
    }

    return (nextPrice * nextSize) / divisor;
  }

  function getDelta(
    uint256 /*marketIndex*/,
    int256 size,
    uint256 averagePrice
  ) public pure returns (bool, uint256) {
    if (averagePrice == 0) revert InvalidAveragePrice();
    uint256 price = 21700 * 1e30;
    uint256 priceDelta;
    unchecked {
      priceDelta = averagePrice > price
        ? averagePrice - price
        : price - averagePrice;
    }
    uint256 delta = (Math.abs(size) * priceDelta) / averagePrice;

    bool isProfit;
    if (size > 0) {
      isProfit = price > averagePrice;
    } else {
      isProfit = price < averagePrice;
    }

    return (isProfit, delta);
  }

  function increaseReserved(uint256 reservedValue) internal {
    // Get the total AUM
    uint256 aum = ICalculator(calculator).getAum();

    // Retrieve the global state
    IPerpStorage.GlobalState memory _globalState = IPerpStorage(perpStorage)
      .getGlobalState();

    // Increase the reserve value by adding the reservedValue
    _globalState.reserveValueE30 += reservedValue;

    // Check if the new reserve value exceeds the AUM, and revert if it does
    if (aum < _globalState.reserveValueE30) {
      revert InsufficientLiquidity();
    }

    // Update the new reserve value in the IPerpStorage contract
    IPerpStorage(perpStorage).updateReserveValue(_globalState.reserveValueE30);
  }
}
