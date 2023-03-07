// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { MockCalculator } from "./MockCalculator.sol";
import { Calculator } from "@hmx/contracts/Calculator.sol";

contract MockCalculatorWithRealGetNextFundingRate is MockCalculator {
  Calculator public c;

  constructor(
    address _oracle,
    address _vaultStorage,
    address _perpStorage,
    address _configStorage
  ) MockCalculator(_oracle) {
    c = new Calculator(_oracle, _vaultStorage, _perpStorage, _configStorage);
  }

  function getNextFundingRate(
    uint256 _marketIndex,
    uint256 _limitPriceE30
  ) external view override returns (int256, int256, int256) {
    return c.getNextFundingRate(_marketIndex, _limitPriceE30);
  }
}
