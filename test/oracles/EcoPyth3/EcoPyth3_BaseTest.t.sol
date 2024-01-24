// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest, console2 } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IEcoPyth3 } from "@hmx/oracles/interfaces/IEcoPyth3.sol";

contract EcoPyth3_BaseTest is BaseTest {
  IEcoPyth3 internal ecoPyth3;

  function setUp() public virtual {
    ecoPyth3 = Deployer.deployEcoPyth3();
    ecoPyth3.setUpdater(address(this), true);
  }
}
