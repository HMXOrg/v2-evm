// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

contract UpgradeLiquidityService is ConfigJsonRepo {
  address ORDER_EXECUTOR = 0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address configStorageAddress = getJsonAddress(".storages.config");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");

    address liquidityServiceAddress = address(
      new LiquidityService(perpStorageAddress, vaultStorageAddress, configStorageAddress)
    );

    LiquidityHandler liquidityHandler = new LiquidityHandler(
      liquidityServiceAddress,
      getJsonAddress(".oracle.pyth"),
      1
    );
    address liquidityHandlerAddress = address(liquidityHandler);

    liquidityHandler.setOrderExecutor(ORDER_EXECUTOR, true);

    PLPv2 plpV2 = PLPv2(getJsonAddress(".tokens.plp"));
    plpV2.setMinter(getJsonAddress(".services.liquidity"), true);

    IConfigStorage(configStorageAddress).setServiceExecutor(liquidityServiceAddress, liquidityHandlerAddress, true);
    IVaultStorage(vaultStorageAddress).setServiceExecutors(liquidityServiceAddress, true);

    vm.stopBroadcast();
    updateJson(".services.liquidity", liquidityServiceAddress);
    updateJson(".handlers.liquidity", liquidityHandlerAddress);
  }
}
