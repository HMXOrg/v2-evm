// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract Calculator_BaseWithStorage is BaseTest {
  function setUp() public virtual {
    calculator = Deployer.deployCalculator(
      address(proxyAdmin),
      address(mockOracle),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );

    vaultStorage.setServiceExecutors(address(this), true);
    vaultStorage.setServiceExecutors(address(calculator), true);
  }
}
