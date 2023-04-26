// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployLiquidityService is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address configStorageAddress = getJsonAddress(".storages.config");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address calculatorAddress = getJsonAddress(".calculator");
    address tradeHelperAddress = getJsonAddress(".helpers.trade");
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    address liquidityServiceAddress = address(
      Deployer.deployLiquidityService(
        address(proxyAdmin),
        perpStorageAddress,
        vaultStorageAddress,
        configStorageAddress
      )
    );

    vm.stopBroadcast();

    updateJson(".services.liquidity", liquidityServiceAddress);
  }
}
