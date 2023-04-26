// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { BotHandler } from "@hmx/handlers/BotHandler.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployHandlers is ConfigJsonRepo {
  struct ContractAddress {
    address pythAddress;
    address tradeServiceAddress;
    address liquidationServiceAddress;
    address liquidityServiceAddress;
    address crossMarginServiceAddress;
    address weth;
  }

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    ContractAddress memory vars = ContractAddress(
      getJsonAddress(".oracles.pyth"),
      getJsonAddress(".services.trade"),
      getJsonAddress(".services.liquidation"),
      getJsonAddress(".services.liquidity"),
      getJsonAddress(".services.crossMargin"),
      getJsonAddress(".tokens.weth")
    );

    // @todo - TBD
    uint256 minExecutionFee = 0;
    uint256 executionOrderFee = 0.0001 ether;

    address botHandlerAddress = address(
      Deployer.deployBotHandler(
        address(proxyAdmin),
        vars.tradeServiceAddress,
        vars.liquidationServiceAddress,
        vars.pythAddress
      )
    );
    address crossMarginHandlerAddress = address(
      Deployer.deployCrossMarginHandler(
        address(proxyAdmin),
        vars.crossMarginServiceAddress,
        vars.pythAddress,
        executionOrderFee
      )
    );
    address liquidityHandlerAddress = address(
      Deployer.deployLiquidityHandler(
        address(proxyAdmin),
        vars.liquidityServiceAddress,
        vars.pythAddress,
        executionOrderFee
      )
    );

    address marketTradeHandlerAddress = address(
      Deployer.deployMarketTradeHandler(address(proxyAdmin), vars.tradeServiceAddress, vars.pythAddress)
    );
    address limitTradeHandlerAddress = address(
      Deployer.deployLimitTradeHandler(
        address(proxyAdmin),
        vars.weth,
        vars.tradeServiceAddress,
        vars.pythAddress,
        minExecutionFee
      )
    );

    vm.stopBroadcast();

    updateJson(".handlers.bot", botHandlerAddress);
    updateJson(".handlers.crossMargin", crossMarginHandlerAddress);
    updateJson(".handlers.limitTrade", limitTradeHandlerAddress);
    updateJson(".handlers.liquidity", liquidityHandlerAddress);
    updateJson(".handlers.marketTrade", marketTradeHandlerAddress);
  }
}
