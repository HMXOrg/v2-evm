// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";

abstract contract LiquidityService_Base is BaseTest {
  ILiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = Deployer.deployLiquidityService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );

    // set this Test to be service executor
    configStorage.setServiceExecutor(address(liquidityService), address(this), true);
    vaultStorage.setServiceExecutors(address(liquidityService), true);

    plp.setMinter(address(liquidityService), true);
  }
}
