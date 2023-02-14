// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OracleMiddleware_BaseTest } from "./OracleMiddleware_BaseTest.t.sol";
import { OracleMiddleware } from "../../src/oracle/OracleMiddleware.sol";

contract OracleMiddleware_GetPriceTest is OracleMiddleware_BaseTest {
  function setUp() public override {
    super.setUp();
  }
}
