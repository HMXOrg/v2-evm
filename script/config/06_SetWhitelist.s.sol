// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract SetWhitelist is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address ORDER_EXECUTOR = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;

    address crossMarginServiceAddress = getJsonAddress(".services.crossMargin");
    address liquidityServiceAddress = getJsonAddress(".services.liquidity");
    address liquidationServiceAddress = getJsonAddress(".services.liquidation");
    address tradeServiceAddress = getJsonAddress(".services.trade");

    address crossMarginHandlerAddress = getJsonAddress(".handlers.crossMargin");
    address liquidityHandlerAddress = getJsonAddress(".handlers.liquidity");
    address botHandlerAddress = getJsonAddress(".handlers.bot");
    address limitTradeHandlerAddress = getJsonAddress(".handlers.limitTrade");
    address marketTradeHandlerAddress = getJsonAddress(".handlers.marketTrade");

    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));
    IVaultStorage vaultStorage = IVaultStorage(getJsonAddress(".storages.vault"));
    ILimitTradeHandler limitTradeHandler = ILimitTradeHandler(limitTradeHandlerAddress);
    ILiquidityHandler liquidityHandler = ILiquidityHandler(liquidityHandlerAddress);

    // Set order executors
    limitTradeHandler.setOrderExecutor(ORDER_EXECUTOR, true);
    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);

    // Set Cross margin executors
    configStorage.setServiceExecutor(crossMarginServiceAddress, crossMarginHandlerAddress, true);

    // Set Liquidity service executors
    configStorage.setServiceExecutor(liquidityServiceAddress, liquidityHandlerAddress, true);

    // Set Liquidation service executors
    configStorage.setServiceExecutor(liquidationServiceAddress, botHandlerAddress, true);

    // Set Trade service executors
    configStorage.setServiceExecutor(tradeServiceAddress, limitTradeHandlerAddress, true);
    configStorage.setServiceExecutor(tradeServiceAddress, marketTradeHandlerAddress, true);
    configStorage.setServiceExecutor(tradeServiceAddress, botHandlerAddress, true);

    vaultStorage.setServiceExecutors(liquidityServiceAddress, true);
    vaultStorage.setServiceExecutors(crossMarginServiceAddress, true);

    vm.stopBroadcast();
  }
}
