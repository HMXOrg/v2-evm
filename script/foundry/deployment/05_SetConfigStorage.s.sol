// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";

contract SetConfigStorage is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    IConfigStorage configStorage = IConfigStorage(getJsonAddress(".storages.config"));
    address calculatorAddress = getJsonAddress(".calculator");
    address hlpAddress = getJsonAddress(".tokens.hlp");
    address wethAddress = getJsonAddress(".tokens.weth");
    address oracleMiddlewareAddress = getJsonAddress(".oracles.middleware");

    configStorage.setCalculator(calculatorAddress);
    configStorage.setHLP(hlpAddress);
    configStorage.setOracle(oracleMiddlewareAddress);
    configStorage.setWeth(wethAddress);

    vm.stopBroadcast();
  }
}
