// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "../../base/BaseTest.sol";

import { BaseTest, LiquidityHandler, IPerpStorage, IConfigStorage } from "../../base/BaseTest.sol";

contract LiquidityHandler_Base is BaseTest {
  LiquidityHandler liquidityHandler;

  function setUp() public virtual {
    liquidityHandler = deployLiquidityHandler(address(mockLiquidityService), address(mockPyth), 5 ether);

    plp.setMinter(address(this), true);
  }
}
