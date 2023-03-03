// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "../../base/BaseTest.sol";
import {PoolConfig} from "../../../src/core/PoolConfig.sol";

abstract contract PoolConfig_BaseTest is BaseTest {
  PoolConfig poolConfig;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();
    poolConfig = deployed.poolConfig;
  }
}
