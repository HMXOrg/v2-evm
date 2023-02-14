// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "../base/BaseTest.sol";
import { PythAdapter } from "../../src/oracle/PythAdapter.sol";

contract PythAdapter_BaseTest is BaseTest {
  PythAdapter pythAdapter;

  function setUp() public virtual {
    DeployReturnVars memory deployed = deployPerp88v2();
    pythAdapter = deployed.pythAdapter;
  }

  function test_Up() external {
    int64[] memory priceData = new int64[](4);
    priceData[0] = 1_000;
    priceData[1] = 23_000;
    priceData[2] = 1;
    priceData[3] = 1;
    bytes[] memory pythUpdateData = buildPythUpdateData(priceData);

    pythAdapter.updatePrices{ value: 4 }(pythUpdateData);
  }
}
