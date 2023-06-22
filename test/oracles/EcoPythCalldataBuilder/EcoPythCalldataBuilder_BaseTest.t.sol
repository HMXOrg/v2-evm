// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

contract EcoPythCalldataBuilder_BaseTest is BaseTest {
  IEcoPythCalldataBuilder internal ecoPythCalldataBuilder;

  function setUp() public virtual {
    // Mint sGLP here so that supply is = 1 sGLP
    sglp.mint(address(this), 1 * 1e18);
    ecoPyth.setUpdater(address(this), true);
    ecoPythCalldataBuilder = Deployer.deployEcoPythCalldataBuilder(
      address(ecoPyth),
      address(sglp),
      address(mockGlpManager)
    );
  }
}
