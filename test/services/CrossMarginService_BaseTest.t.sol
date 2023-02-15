// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, CrossMarginService } from "../base/BaseTest.sol";

contract CrossMarginService_BaseTest is BaseTest {
  CrossMarginService crossMarginService;

  function setUp() public virtual {
    // @todo - implement Mock contract here
    address configStorage = address(1);
    address vaultStorage = address(2);
    address calculator = address(3);

    crossMarginService = deployCrossMarginService(
      configStorage,
      vaultStorage,
      calculator
    );
  }
}
