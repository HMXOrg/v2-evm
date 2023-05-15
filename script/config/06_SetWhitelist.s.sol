// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";

contract SetWhitelist is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address ORDER_EXECUTOR = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;

    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));
    IVaultStorage vaultStorage = IVaultStorage(getJsonAddress(".storages.vault"));
    IPerpStorage perpStorage = IPerpStorage(getJsonAddress(".storages.perp"));
    ILimitTradeHandler limitTradeHandler = ILimitTradeHandler(getJsonAddress(".handlers.limitTrade"));
    ILiquidityHandler liquidityHandler = ILiquidityHandler(getJsonAddress(".handlers.liquidity"));

    // Set order executors
    limitTradeHandler.setOrderExecutor(ORDER_EXECUTOR, true);
    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);

    // Set Cross margin executors
    configStorage.setServiceExecutor(
      getJsonAddress(".services.crossMargin"),
      getJsonAddress(".handlers.crossMargin"),
      true
    );

    // Set Liquidity service executors
    configStorage.setServiceExecutor(
      getJsonAddress(".services.liquidity"),
      getJsonAddress(".handlers.liquidity"),
      true
    );

    // Set Liquidation service executors
    configStorage.setServiceExecutor(getJsonAddress(".services.liquidation"), getJsonAddress(".handlers.bot"), true);

    // Set Trade service executors
    configStorage.setServiceExecutor(getJsonAddress(".services.trade"), getJsonAddress(".handlers.limitTrade"), true);
    configStorage.setServiceExecutor(getJsonAddress(".services.trade"), getJsonAddress(".handlers.marketTrade"), true);
    configStorage.setServiceExecutor(getJsonAddress(".services.trade"), getJsonAddress(".handlers.bot"), true);
    configStorage.setServiceExecutor(getJsonAddress(".helpers.trade"), getJsonAddress(".services.trade"), true);

    vaultStorage.setServiceExecutors(getJsonAddress(".services.liquidity"), true);
    vaultStorage.setServiceExecutors(getJsonAddress(".services.crossMargin"), true);
    vaultStorage.setServiceExecutors(getJsonAddress(".services.trade"), true);
    vaultStorage.setServiceExecutors(getJsonAddress(".feeCalculator"), true);
    vaultStorage.setServiceExecutors(getJsonAddress(".helpers.trade"), true);

    perpStorage.setServiceExecutors(getJsonAddress(".services.trade"), true);
    perpStorage.setServiceExecutors(getJsonAddress(".services.crossMargin"), true);
    perpStorage.setServiceExecutors(getJsonAddress(".helpers.trade"), true);
    vm.stopBroadcast();
  }
}
