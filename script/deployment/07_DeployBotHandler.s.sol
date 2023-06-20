// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployBotHandler is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    address pythAddress = getJsonAddress(".oracles.ecoPyth");
    address tradeServiceAddress = getJsonAddress(".services.trade");
    address crossMarginServiceAddress = getJsonAddress(".services.crossMargin");
    address liquidationServiceAddress = getJsonAddress(".services.liquidation");

    address botHandlerAddress = address(
      Deployer.deployBotHandler(
        address(proxyAdmin),
        tradeServiceAddress,
        liquidationServiceAddress,
        crossMarginServiceAddress,
        pythAddress
      )
    );

    vm.stopBroadcast();

    updateJson(".handlers.bot", botHandlerAddress);
  }
}
