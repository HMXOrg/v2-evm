// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployMarketTradeHandler is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    address pythAddress = getJsonAddress(".oracles.ecoPyth");
    address tradeServiceAddress = getJsonAddress(".services.trade");

    address marketTradeHandlerAddress = address(
      Deployer.deployMarketTradeHandler(address(proxyAdmin), tradeServiceAddress, pythAddress)
    );

    vm.stopBroadcast();

    updateJson(".handlers.marketTrade", marketTradeHandlerAddress);
  }
}
