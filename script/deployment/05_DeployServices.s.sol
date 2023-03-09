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

    address crossMarginServiceAddress = address(
      new CrossMarginService(configStorageAddress, vaultStorageAddress, calculatorAddress)
    );
    address liquidationServiceAddress = address(
      new LiquidationService(perpStorageAddress, vaultStorageAddress, configStorageAddress)
    );
    address liquidityServiceAddress = address(
      new LiquidityService(configStorageAddress, vaultStorageAddress, perpStorageAddress)
    );
    address tradeServiceAddress = address(
      new TradeService(perpStorageAddress, vaultStorageAddress, configStorageAddress)
    );

    vm.stopBroadcast();

    updateJson(".crossMargin", crossMarginServiceAddress);
    updateJson(".liquidation", liquidationServiceAddress);
    updateJson(".liquidity", liquidityServiceAddress);
    updateJson(".trade", tradeServiceAddress);
  }
}
