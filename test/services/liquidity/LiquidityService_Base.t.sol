// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { console } from "forge-std/console.sol";

import { BaseTest } from "../../base/BaseTest.sol";

import { LiquidityService } from "../../../src/services/LiquidityService.sol";
import { IConfigStorage } from "../../../src/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "../../../src/storages/interfaces/IPerpStorage.sol";

abstract contract LiquidityService_Base is BaseTest {
  LiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = new LiquidityService(
      address(configStorage),
      address(vaultStorage),
      address(perpStorage)
    );

    // set this Test to be service executor
    configStorage.setServiceExecutor(
      address(liquidityService),
      address(this),
      true
    );
  }
}
