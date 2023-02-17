// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, Calculator, IPerpStorage } from "../base/BaseTest.sol";

contract Calculator_Base is BaseTest {
  function setUp() public virtual {
    calculator = deployCalculator(
      address(mockOracle),
      address(mockVaultStorage),
      address(mockPerpStorage),
      address(configStorage)
    );
  }
}
