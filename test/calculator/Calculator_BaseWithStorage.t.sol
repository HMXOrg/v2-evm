// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, Calculator, IPerpStorage } from "@hmx-test/base/BaseTest.sol";

contract Calculator_BaseWithStorage is BaseTest {
  function setUp() public virtual {
    calculator = deployCalculator(
      address(mockOracle),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );
  }
}
