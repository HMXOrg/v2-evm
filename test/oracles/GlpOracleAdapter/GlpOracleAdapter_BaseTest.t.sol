// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { GlpOracleAdapter } from "@hmx/oracles/GlpOracleAdapter.sol";

contract GlpOracleAdapter_BaseTest is BaseTest {
  GlpOracleAdapter glpOracleAdapter;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();
    glpOracleAdapter = deployed.glpOracleAdapter;
  }
}
