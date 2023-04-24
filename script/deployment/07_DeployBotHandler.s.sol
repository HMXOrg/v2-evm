// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";

contract DeployBotHandler is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address pythAddress = getJsonAddress(".oracle.ecoPyth");
    address tradeServiceAddress = getJsonAddress(".services.trade");
    address liquiditionServiceAddress = getJsonAddress(".services.liquidation");
    address liquidityServiceAddress = getJsonAddress(".services.liquidity");
    address crossMarginServiceAddress = getJsonAddress(".services.crossMargin");
    address weth = getJsonAddress(".tokens.weth");
    // @todo - TBD
    uint256 minExecutionFee = 30;

    address botHandlerAddress = address(new BotHandler(tradeServiceAddress, liquiditionServiceAddress, pythAddress));

    vm.stopBroadcast();

    updateJson(".handlers.bot", botHandlerAddress);
  }
}
