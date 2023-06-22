// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { BaseTest, IPerpStorage, IConfigStorage } from "../../base/BaseTest.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract LiquidityHandler_Base is BaseTest {
  ILiquidityHandler liquidityHandler;

  function setUp() public virtual {
    liquidityHandler = Deployer.deployLiquidityHandler(
      address(proxyAdmin),
      address(mockLiquidityService),
      address(ecoPyth),
      5 ether,
      10
    );
    hlp.setMinter(address(this), true);
    mockLiquidityService.setHlpEnabled(true);

    ecoPyth.setUpdater(address(liquidityHandler), true);
  }
}
