// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, LimitTradeHandler, IPerpStorage, IConfigStorage } from "@hmx-test/base/BaseTest.sol";
import { LimitOrderTester } from "@hmx-test/testers/LimitOrderTester.sol";

contract LimitTradeHandler_Base is BaseTest {
  uint8 internal constant INCREASE = 0;
  uint8 internal constant DECREASE = 1;

  LimitTradeHandler limitTradeHandler;
  LimitOrderTester limitOrderTester;

  function setUp() public virtual {
    limitTradeHandler = deployLimitTradeHandler(address(weth), address(mockTradeService), address(mockPyth), 0.1 ether);

    mockTradeService.setConfigStorage(address(configStorage));
    mockTradeService.setPerpStorage(address(mockPerpStorage));

    limitOrderTester = new LimitOrderTester(limitTradeHandler);
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }
}
