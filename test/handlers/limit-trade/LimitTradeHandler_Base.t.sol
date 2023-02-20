// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, LimitTradeHandler, IPerpStorage, IConfigStorage } from "../../base/BaseTest.sol";

contract LimitTradeHandler_Base is BaseTest {
  LimitTradeHandler limitTradeHandler;

  function setUp() public virtual {
    limitTradeHandler = deployLimitTradeHandler(address(weth), address(mockTradeService), address(mockPyth), 0.1 ether);

    mockTradeService.setConfigStorage(address(configStorage));
    mockTradeService.setPerpStorage(address(mockPerpStorage));
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function _getSubAccount(address primary, uint256 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }
}
