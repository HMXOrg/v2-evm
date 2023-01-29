// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "../../base/BaseTest.sol";
import {Deployment} from "../../../script/Deployment.s.sol";
import {PoolConfig} from "../../../src/core/PoolConfig.sol";

abstract contract PoolConfig_BaseTest is BaseTest, Deployment {
  PoolConfig poolConfig;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deploy();
    poolConfig = deployed.poolConfig;
  }
}
