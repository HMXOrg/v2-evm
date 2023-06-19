// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";

contract EcoPyth_BaseTest is BaseTest {
  function setUp() public virtual {
    ecoPyth.setUpdater(address(this), true);
  }
}
