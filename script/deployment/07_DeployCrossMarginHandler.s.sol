// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployCrossMarginHandler is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address pythAddress = getJsonAddress(".oracles.ecoPyth");
    address crossMarginServiceAddress = getJsonAddress(".services.crossMargin");
    uint256 minExecutionFee = 30;
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    address gmxRewardRouter = getJsonAddress(".yieldSources.gmx.rewardRouterV2");

    address crossMarginHandlerAddress = address(
      Deployer.deployCrossMarginHandler(
        address(proxyAdmin),
        crossMarginServiceAddress,
        pythAddress,
        minExecutionFee,
        gmxRewardRouter
      )
    );

    vm.stopBroadcast();

    updateJson(".handlers.crossMargin", crossMarginHandlerAddress);
  }
}
