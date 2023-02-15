// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, CrossMarginService } from "../base/BaseTest.sol";

contract CrossMarginService_BaseTest is BaseTest {
  CrossMarginService crossMarginService;

  function setUp() public virtual {
    crossMarginService = deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(mockCalculator)
    );
  }
}
