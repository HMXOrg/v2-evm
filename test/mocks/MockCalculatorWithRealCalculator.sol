// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockCalculator } from "./MockCalculator.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";

contract MockCalculatorWithRealCalculator is MockCalculator {
  Calculator public c;
  mapping(bytes32 => bool) public actualFunction;

  constructor(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) MockCalculator(_oracle) {
    c = new Calculator(_oracle, _vaultStorage, _perpStorage, _configStorage);
  }

  function useActualFunction(bytes memory _funcName) external {
    actualFunction[keccak256(_funcName)] = true;
  }

  function getNextFundingRate(
    uint256 _marketIndex,
    uint256 _limitPriceE30
  ) public view virtual override returns (int256, int256, int256) {
    if (actualFunction[keccak256("getNextFundingRate")]) {
      return c.getNextFundingRate(_marketIndex, _limitPriceE30);
    } else {
      return super.getNextFundingRate(_marketIndex, _limitPriceE30);
    }
  }

  function calculateShortAveragePrice(
    PerpStorage.GlobalMarket memory _market,
    uint256 _currentPrice,
    int256 _positionSizeDelta,
    int256 _realizedPositionPnl
  ) public view override returns (uint256 _nextAveragePrice) {
    if (actualFunction[keccak256("calculateShortAveragePrice")]) {
      return c.calculateShortAveragePrice(_market, _currentPrice, _positionSizeDelta, _realizedPositionPnl);
    } else {
      return super.calculateShortAveragePrice(_market, _currentPrice, _positionSizeDelta, _realizedPositionPnl);
    }
  }

  function calculateLongAveragePrice(
    PerpStorage.GlobalMarket memory _market,
    uint256 _currentPrice,
    int256 _positionSizeDelta,
    int256 _realizedPositionPnl
  ) public view override returns (uint256 _nextAveragePrice) {
    if (actualFunction[keccak256("calculateLongAveragePrice")]) {
      return c.calculateLongAveragePrice(_market, _currentPrice, _positionSizeDelta, _realizedPositionPnl);
    } else {
      return super.calculateLongAveragePrice(_market, _currentPrice, _positionSizeDelta, _realizedPositionPnl);
    }
  }
}
