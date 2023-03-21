// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";

contract DeployCalculators is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address oracleMiddlewareAddress = getJsonAddress(".oracle.middleware");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address configStorageAddress = getJsonAddress(".storages.config");

    address calculatorAddress = address(
      new Calculator(oracleMiddlewareAddress, vaultStorageAddress, perpStorageAddress, configStorageAddress)
    );

    vm.stopBroadcast();

    updateJson(".calculator", calculatorAddress);
  }
}
