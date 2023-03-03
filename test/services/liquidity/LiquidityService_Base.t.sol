// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";

abstract contract LiquidityService_Base is BaseTest {
  ILiquidityService liquidityService;

  function setUp() public virtual {
    // deploy liquidity service
    liquidityService = ILiquidityService(
      Deployer.deployContractWithArguments(
        "LiquidityService",
        abi.encode(address(configStorage), address(vaultStorage), address(perpStorage))
      )
    );

    // set this Test to be service executor
    configStorage.setServiceExecutor(address(liquidityService), address(this), true);
  }
}
