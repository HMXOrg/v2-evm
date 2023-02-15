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

  function increasePosition(
    address _primaryAccount,
    uint256 _subAccountId,
    uint256 _marketIndex,
    int256 _sizeDelta
  ) external {
    // get the sub-account from the primary account and sub-account ID
    address _subAccount = getSubAccount(_primaryAccount, _subAccountId);

    // get the position for the given sub-account and market index
    bytes32 _posId = getPositionId(_subAccount, _marketIndex);
    IPerpStorage.Position memory _position = IPerpStorage(perpStorage)
      .getPositionById(_posId);

    // set the price to a fixed value of 21700 * 1e30
    uint256 _price = 21700 * 1e30;

    // determine whether the new size delta is for a long position
    bool isLong = _sizeDelta > 0;

    // if the position size is zero, set the average price to the current price (new position)
    if (_position.sizeE30 == 0) {
      _position.avgPriceE30 = _price;
    }

    // if the position size is not zero and the new size delta is not zero, calculate the new average price (adjust position)
    if (_position.sizeE30 != 0 && _sizeDelta != 0) {
      _position.avgPriceE30 = getPositionNextAveragePrice(
        _marketIndex,
        _position.sizeE30,
        isLong,
        _sizeDelta,
        _position.avgPriceE30,
        _price
      );
    }

    // TODO: Collect trading fee, borrowing fee, update borrowing rate, collect funding fee, and update funding rate.

    // update the position size by adding the new size delta
    _position.sizeE30 += _sizeDelta;

    // if the position size is zero after the update, revert the transaction with an error
    if (_position.sizeE30 == 0) revert ITradeService_BadPositionSize();

    // get the absolute value of the new size delta
    uint256 _absSizeDelta = Math.abs(_sizeDelta);

    // get the market configuration for the given market index
    IConfigStorage.MarketConfig memory _marketConfig = IConfigStorage(
      configStorage
    ).getMarketConfigs(_marketIndex);

    // get the amount of free collateral available for the sub-account
    uint256 subAccountFreeCollateral = ICalculator(calculator)
      .getFreeCollateral(_subAccount);

    // calculate the initial margin required for the new position
    uint256 _imr = (_absSizeDelta * _marketConfig.initialMarginFraction) / 1e18;

    // if the free collateral is less than the initial margin required, revert the transaction with an error
    if (subAccountFreeCollateral < _imr)
      revert ITradeService_InsufficientFreeCollateral();

    // calculate the maximum amount of reserve required for the new position
    uint256 _maxReserve = (_imr * _marketConfig.maxProfitRate) / 1e18;

    // increase the reserved amount by the maximum reserve required for the new position
    increaseReserved(_maxReserve);

    // save the updated position to the storage
    IPerpStorage(perpStorage).savePosition(_posId, _position);

    // get the global market for the given market index
    IPerpStorage.GlobalMarket memory _globalMarket = IPerpStorage(perpStorage)
      .getGlobalMarketById(_marketIndex);

    // calculate the change in open interest for the new position
    uint256 _changedOpenInterest = (_absSizeDelta * 1e30) / _price;

    // update gobal market state
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
    if (_subAccountId > 255) revert ITradeService_BadSubAccountId();
    return address(uint160(_primary) ^ uint160(_subAccountId));
  }

  /// @notice Calculates the next average price of a position, given the current position details and the next price.
  /// @param marketIndex The index of the market.
  /// @param size The current size of the position.
  /// @param isLong Whether the position is long or short.
  /// @param sizeDelta The size difference between the current position and the next position.
  /// @param averagePrice The current average price of the position.
  /// @param nextPrice The next price of the position.
  /// @return The next average price of the position.
  function getPositionNextAveragePrice(
    uint256 marketIndex,
    int256 size,
    bool isLong,
    int256 sizeDelta,
    uint256 averagePrice,
    uint256 nextPrice
  ) internal pure returns (uint256) {
    // Get the delta and isProfit value from the getDelta function
    (bool isProfit, uint256 delta) = getDelta(
      marketIndex,
      size,
      isLong,
      averagePrice
    );
    // Calculate the next size and divisor
    uint256 nextSize = Math.abs(size + sizeDelta);
    uint256 divisor;
    if (size > 0) {
      divisor = isProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = isProfit ? nextSize - delta : nextSize + delta;
    }

    // Calculate the next average price of the position
    return (nextPrice * nextSize) / divisor;
  }

  /// @notice Calculates the delta between average price and mark price, based on the size of position and whether the position is profitable.
  /// @param size The size of the position.
  /// @param averagePrice The average price of the position.
  /// @return isProfit A boolean value indicating whether the position is profitable or not.
  /// @return delta The Profit between the average price and the fixed price, adjusted for the size of the order.
  function getDelta(
    uint256 /*marketIndex*/,
    int256 size,
    bool isLong,
    uint256 averagePrice
  ) public pure returns (bool, uint256) {
    // Check for invalid input: averagePrice cannot be zero.
    if (averagePrice == 0) revert ITradeService_InvalidAveragePrice();

    // Set the fixed price.
    uint256 price = 21700 * 1e30;

    // Calculate the difference between the average price and the fixed price.
    uint256 priceDelta;
    unchecked {
      priceDelta = averagePrice > price
        ? averagePrice - price
        : price - averagePrice;
    }

    // Calculate the delta, adjusted for the size of the order.
    uint256 delta = (Math.abs(size) * priceDelta) / averagePrice;

    // Determine if the position is profitable or not based on the averagePrice and the mark price.
    bool isProfit;
    if (isLong) {
      isProfit = price > averagePrice;
    } else {
      isProfit = price < averagePrice;
    }

    // Return the values of isProfit and delta.
    return (isProfit, delta);
  }

  /// @notice This function increases the reserve value
  /// @param reservedValue The amount by which to increase the reserve value.
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
      revert ITradeService_InsufficientLiquidity();
    }

    // Update the new reserve value in the IPerpStorage contract
    IPerpStorage(perpStorage).updateReserveValue(_globalState.reserveValueE30);
  }
}
