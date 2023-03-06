// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";

contract StakedGlpOracleAdapter_BaseTest is BaseTest {
  StakedGlpOracleAdapter stakedGlpOracleAdapter;

  bytes32 sGlpAssetId = "sGLP";

  function setUp() public virtual {
    DeployCoreReturnVars memory deployed = deployPerp88v2();
    stakedGlpOracleAdapter = deployed.stakedGlpOracleAdapter;
  }
}
