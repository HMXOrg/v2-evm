// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IPerpStorage, IConfigStorage } from "@hmx-test/base/BaseTest.sol";

import { IMarketTradeHandler } from "@hmx/handlers/interfaces/IMarketTradeHandler.sol";

contract MarketTradeHandler_Base is BaseTest {
  IMarketTradeHandler marketTradeHandler;
  bytes[] prices;

  function setUp() public virtual {
    prices = new bytes[](0);

    marketTradeHandler = deployMarketTradeHandler(address(mockTradeService), address(mockPyth));
    mockTradeService.setConfigStorage(address(configStorage));
    mockTradeService.setPerpStorage(address(mockPerpStorage));
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }
}
