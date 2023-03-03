// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";

import { LiquidityService } from "@hmx/services/LiquidityService.sol";

abstract contract LiquidityService_Base is BaseTest {
  LiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = new LiquidityService(address(configStorage), address(vaultStorage), address(perpStorage));

    // set this Test to be service executor
    configStorage.setServiceExecutor(address(liquidityService), address(this), true);
  }
}
