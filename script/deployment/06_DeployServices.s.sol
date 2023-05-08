// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";

import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployServices is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    ProxyAdmin proxyAdmin = new ProxyAdmin();
    address configStorageAddress = getJsonAddress(".storages.config");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address calculatorAddress = getJsonAddress(".calculator");
    address tradeHelperAddress = getJsonAddress(".helpers.trade");
    address convertedGlpStrategyAddress = getJsonAddress(".strategies.convertedGlpStrategy");
    address proxyAdminAddress = address(proxyAdmin);
    address crossMarginServiceAddress = address(
      Deployer.deployCrossMarginService(
        proxyAdminAddress,
        configStorageAddress,
        vaultStorageAddress,
        calculatorAddress,
        perpStorageAddress,
        convertedGlpStrategyAddress
      )
    );
    address liquidationServiceAddress = address(
      Deployer.deployLiquidationService(
        proxyAdminAddress,
        perpStorageAddress,
        vaultStorageAddress,
        configStorageAddress,
        tradeHelperAddress
      )
    );
    address liquidityServiceAddress = address(
      Deployer.deployLiquidityService(proxyAdminAddress, configStorageAddress, vaultStorageAddress, perpStorageAddress)
    );
    address tradeServiceAddress = address(
      Deployer.deployTradeService(
        proxyAdminAddress,
        perpStorageAddress,
        vaultStorageAddress,
        configStorageAddress,
        tradeHelperAddress
      )
    );

    vm.stopBroadcast();

    updateJson(".services.crossMargin", crossMarginServiceAddress);
    updateJson(".services.liquidation", liquidationServiceAddress);
    updateJson(".services.liquidity", liquidityServiceAddress);
    updateJson(".services.trade", tradeServiceAddress);
  }
}
