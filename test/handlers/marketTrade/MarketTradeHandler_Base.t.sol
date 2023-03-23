// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { BaseTest, IPerpStorage, IConfigStorage } from "@hmx-test/base/BaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

import { IMarketTradeHandler } from "@hmx/handlers/interfaces/IMarketTradeHandler.sol";

struct Price {
  // Price
  int64 price;
  // Confidence interval around the price
  uint64 conf;
  // Price exponent
  int32 expo;
  // Unix timestamp describing when the price was published
  uint publishTime;
}

// PriceFeed represents a current aggregate price from pyth publisher feeds.
struct PriceFeed {
  // The price ID.
  bytes32 id;
  // Latest available price
  Price price;
  // Latest available exponentially-weighted moving average price
  Price emaPrice;
}

contract MarketTradeHandler_Base is BaseTest {
  IMarketTradeHandler marketTradeHandler;
  bytes[] prices;

  function setUp() public virtual {
    prices = new bytes[](1);
    prices[0] = abi.encode(
      PriceFeed({
        id: "1234",
        price: Price({ price: 0, conf: 0, expo: 0, publishTime: block.timestamp }),
        emaPrice: Price({ price: 0, conf: 0, expo: 0, publishTime: block.timestamp })
      })
    );

    marketTradeHandler = Deployer.deployMarketTradeHandler(address(mockTradeService), address(leanPyth));
    mockTradeService.setConfigStorage(address(configStorage));
    mockTradeService.setPerpStorage(address(mockPerpStorage));

    // Whitelist price updater
    leanPyth.setUpdater(address(marketTradeHandler), true);
  }

  // =========================================
  // | ------- common function ------------- |
  // =========================================

  function _getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
    return address(uint160(primary) ^ uint160(subAccountId));
  }
}
