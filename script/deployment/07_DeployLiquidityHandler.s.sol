// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployLiquidityHandler is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    address pythAddress = getJsonAddress(".oracles.ecoPyth");
    address liquidityServiceAddress = getJsonAddress(".services.liquidity");
    // @todo - TBD
    uint256 minExecutionFee = 30;

    address liquidityHandlerAddress = address(
      Deployer.deployLiquidityHandler(address(proxyAdmin), liquidityServiceAddress, pythAddress, minExecutionFee)
    );

    vm.stopBroadcast();

    updateJson(".handlers.liquidity", liquidityHandlerAddress);
  }
}
