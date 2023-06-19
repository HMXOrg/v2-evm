// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";

contract EcoPythCalldataBuilder_BaseTest is BaseTest {
  IEcoPythCalldataBuilder internal ecoPythCalldataBuilder;

  function setUp() public virtual {
    ecoPyth.setUpdater(address(this), true);
    ecoPythCalldataBuilder = Deployer.deployEcoPythCalldataBuilder(address(ecoPyth));
  }
}
