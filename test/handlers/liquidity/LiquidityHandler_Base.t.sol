// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";

import { BaseTest, LiquidityHandler, IPerpStorage, IConfigStorage } from "@hmx-test/base/BaseTest.sol";

contract LiquidityHandler_Base is BaseTest {
  LiquidityHandler liquidityHandler;

  function setUp() public virtual {
    liquidityHandler = deployLiquidityHandler(address(mockLiquidityService), address(mockPyth), 5 ether);
  }
}
