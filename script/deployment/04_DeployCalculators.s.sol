// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";

import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployCalculators is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    address oracleMiddlewareAddress = getJsonAddress(".oracles.middleware");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address configStorageAddress = getJsonAddress(".storages.config");

    address calculatorAddress = address(
      Deployer.deployCalculator(
        address(proxyAdmin),
        oracleMiddlewareAddress,
        vaultStorageAddress,
        perpStorageAddress,
        configStorageAddress
      )
    );

    vm.stopBroadcast();

    updateJson(".calculator", calculatorAddress);
  }
}
