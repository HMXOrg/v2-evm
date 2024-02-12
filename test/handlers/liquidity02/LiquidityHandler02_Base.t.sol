// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { BaseTest, IPerpStorage, IConfigStorage } from "../../base/BaseTest.sol";

import { ILiquidityHandler02 } from "@hmx/handlers/interfaces/ILiquidityHandler02.sol";

contract LiquidityHandler02_Base is BaseTest {
  ILiquidityHandler02 liquidityHandler;
  uint8 internal constant SUB_ID = 0;

  function setUp() public virtual {
    liquidityHandler = Deployer.deployLiquidityHandler02(
      address(proxyAdmin),
      address(mockLiquidityService),
      address(ecoPyth),
      5 ether
    );
    hlp.setMinter(address(this), true);
    mockLiquidityService.setHlpEnabled(true);

    ecoPyth.setUpdater(address(liquidityHandler), true);
  }
}
