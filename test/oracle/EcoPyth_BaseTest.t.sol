// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { EcoPyth } from "@hmx/oracle/EcoPyth.sol";

contract EcoPyth_BaseTest is BaseTest {
  EcoPyth ecoPyth;

  function setUp() public virtual {
    ecoPyth = new EcoPyth();
  }
}
