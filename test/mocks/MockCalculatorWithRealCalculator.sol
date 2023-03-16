// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockCalculator } from "./MockCalculator.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { console } from "forge-std/console.sol";

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

  function getFundingFee(
    uint256 _marketIndex,
    bool _isLong,
    int256 _size,
    int256 _entryFundingRate
  ) public view override returns (int256) {
    if (actualFunction[keccak256("getFundingFee")]) {
      return c.getFundingFee(_marketIndex, _isLong, _size, _entryFundingRate);
    } else {
      return super.getFundingFee(_marketIndex, _isLong, _size, _entryFundingRate);
    }
  }

  function getBorrowingFee(
    uint8 _assetClassIndex,
    uint256 _reservedValue,
    uint256 _entryBorrowingRate
  ) public view override returns (uint256 borrowingFee) {
    if (actualFunction[keccak256("getBorrowingFee")]) {
      return c.getBorrowingFee(_assetClassIndex, _reservedValue, _entryBorrowingRate);
    } else {
      return super.getBorrowingFee(_assetClassIndex, _reservedValue, _entryBorrowingRate);
    }
  }

  function getNextFundingRate(
    uint256 _marketIndex,
    uint256 _limitPriceE30
  ) public view virtual override returns (int256) {
    if (actualFunction[keccak256("getNextFundingRate")]) {
      return c.getNextFundingRate(_marketIndex, _limitPriceE30);
    } else {
      return super.getNextFundingRate(_marketIndex, _limitPriceE30);
    }
  }

  function getNextBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) public view override returns (uint256 _nextBorrowingRate) {
    if (actualFunction[keccak256("getNextBorrowingRate")]) {
      return c.getNextBorrowingRate(_assetClassIndex, _limitPriceE30, _limitAssetId);
    } else {
      return super.getNextBorrowingRate(_assetClassIndex, _limitPriceE30, _limitAssetId);
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

  function getPLPValueE30(
    bool _isMaxPrice,
    uint256 _limitPriceE30,
    bytes32 _limitAssetId
  ) public view override returns (uint256 _nextAveragePrice) {
    if (actualFunction[keccak256("getPLPValueE30")]) {
      return c.getPLPValueE30(_isMaxPrice, _limitPriceE30, _limitAssetId);
    } else {
      return super.getPLPValueE30(_isMaxPrice, _limitPriceE30, _limitAssetId);
    }
  }

  function getDelta(
    uint256 _size,
    bool _isLong,
    uint256 _markPrice,
    uint256 _averagePrice,
    uint256 _lastIncreaseTimestamp
  ) public view override returns (bool, uint256) {
    if (actualFunction[keccak256("getDelta")]) {
      return c.getDelta(_size, _isLong, _markPrice, _averagePrice, _lastIncreaseTimestamp);
    } else {
      return super.getDelta(_size, _isLong, _markPrice, _averagePrice, _lastIncreaseTimestamp);
    }
  }
}
