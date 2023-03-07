// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract Calculator_Base is BaseTest {
  function setUp() public virtual {
    calculator = Deployer.deployCalculator(
      address(mockOracle),
      address(mockVaultStorage),
      address(mockPerpStorage),
      address(configStorage)
    );
  }
}
