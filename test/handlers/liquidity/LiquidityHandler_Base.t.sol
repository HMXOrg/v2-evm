// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { BaseTest, IPerpStorage, IConfigStorage } from "../../base/BaseTest.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract LiquidityHandler_Base is BaseTest {
  ILiquidityHandler liquidityHandler;

  function setUp() public virtual {
    liquidityHandler = Deployer.deployLiquidityHandler(address(mockLiquidityService), address(mockPyth), 5 ether);
    plp.setMinter(address(this), true);
  }
}
