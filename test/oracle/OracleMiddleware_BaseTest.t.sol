// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "../base/BaseTest.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";

contract OracleMiddleware_BaseTest is BaseTest {
  OracleMiddleware oracleMiddleware;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();
    oracleMiddleware = deployed.oracleMiddleware;
  }
}
