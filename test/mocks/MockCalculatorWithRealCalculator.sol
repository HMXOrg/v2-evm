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

  function getTradingFee(uint256 _size, uint256 _baseFeeRateBPS) public view override returns (uint256) {
    if (actualFunction[keccak256("getTradingFee")]) {
      return c.getTradingFee(_size, _baseFeeRateBPS);
    } else {
      return super.getTradingFee(_size, _baseFeeRateBPS);
    }
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

  function getNextFundingRate(uint256 _marketIndex) public view virtual override returns (int256) {
    if (actualFunction[keccak256("getNextFundingRate")]) {
      return c.getNextFundingRate(_marketIndex);
    } else {
      return super.getNextFundingRate(_marketIndex);
    }
  }

  function getNextBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _plpTVL
  ) public view override returns (uint256 _nextBorrowingRate) {
    if (actualFunction[keccak256("getNextBorrowingRate")]) {
      return c.getNextBorrowingRate(_assetClassIndex, _plpTVL);
    } else {
      return super.getNextBorrowingRate(_assetClassIndex, _plpTVL);
    }
  }

  function calculateMarketAveragePrice(
    int256 _marketPositionSize,
    uint256 _marketAveragePrice,
    int256 _sizeDelta,
    uint256 _positionClosePrice,
    uint256 _positionNextClosePrice,
    int256 _positionRealizedPnl
  ) public view override returns (uint256 _newAvaragePrice) {
    if (actualFunction[keccak256("calculateMarketAveragePrice")]) {
      return
        c.calculateMarketAveragePrice(
          _marketPositionSize,
          _marketAveragePrice,
          _sizeDelta,
          _positionClosePrice,
          _positionNextClosePrice,
          _positionRealizedPnl
        );
    } else {
      return
        super.calculateMarketAveragePrice(
          _marketPositionSize,
          _marketAveragePrice,
          _sizeDelta,
          _positionClosePrice,
          _positionNextClosePrice,
          _positionRealizedPnl
        );
    }
  }

  function getPLPValueE30(bool _isMaxPrice) public view override returns (uint256 _nextAveragePrice) {
    if (actualFunction[keccak256("getPLPValueE30")]) {
      return c.getPLPValueE30(_isMaxPrice);
    } else {
      return super.getPLPValueE30(_isMaxPrice);
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

  function getPendingBorrowingFeeE30() public view override returns (uint256) {
    if (actualFunction[keccak256("getPendingBorrowingFeeE30")]) {
      return c.getPendingBorrowingFeeE30();
    } else {
      return super.getPendingBorrowingFeeE30();
    }
  }
}
