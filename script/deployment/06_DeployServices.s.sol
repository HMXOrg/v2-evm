// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

contract DeployServices is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address configStorageAddress = getJsonAddress(".storages.config");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address calculatorAddress = getJsonAddress(".calculator");
    address tradeHelperAddress = getJsonAddress(".helpers.trade");

    address crossMarginServiceAddress = address(
      new CrossMarginService(configStorageAddress, vaultStorageAddress, calculatorAddress, perpStorageAddress)
    );
    address liquidationServiceAddress = address(
      new LiquidationService(perpStorageAddress, vaultStorageAddress, configStorageAddress, tradeHelperAddress)
    );
    address liquidityServiceAddress = address(
      new LiquidityService(configStorageAddress, vaultStorageAddress, perpStorageAddress)
    );
    address tradeServiceAddress = address(
      new TradeService(perpStorageAddress, vaultStorageAddress, configStorageAddress, tradeHelperAddress)
    );

    vm.stopBroadcast();

    updateJson(".services.crossMargin", crossMarginServiceAddress);
    updateJson(".services.liquidation", liquidationServiceAddress);
    updateJson(".services.liquidity", liquidityServiceAddress);
    updateJson(".services.trade", tradeServiceAddress);
  }
}
