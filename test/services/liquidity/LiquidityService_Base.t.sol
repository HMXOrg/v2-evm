// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest, IConfigStorage, IVaultStorage, IPerpStorage } from "../../base/BaseTest.sol";

import { LiquidityService } from "@hmx/services/LiquidityService.sol";

abstract contract LiquidityService_Base is BaseTest {
  LiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = new LiquidityService(configStorage, vaultStorage, perpStorage);

    // set this Test to be service executor
    configStorage.setServiceExecutor(address(liquidityService), address(this), true);
  }
}
