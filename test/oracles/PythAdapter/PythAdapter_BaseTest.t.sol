// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";

contract PythAdapter_BaseTest is BaseTest {
  PythAdapter pythAdapter;

  function setUp() public virtual {
    DeployCoreReturnVars memory deployed = deployPerp88v2();
    pythAdapter = deployed.pythAdapter;
  }
}
