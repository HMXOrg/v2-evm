// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, Calculator } from "../base/BaseTest.sol";

contract Calculator_Base is BaseTest {
  Calculator calculator;

  function setUp() public virtual {
    calculator = deployCalculator(
      address(mockOracle),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );

    // Mock some opening positions on ALICE' account
  }
}
