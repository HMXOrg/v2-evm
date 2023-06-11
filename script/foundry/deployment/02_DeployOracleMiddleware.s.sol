// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";

import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";

import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployOracleMiddleware is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");
    uint256 maxTrustPriceAge = 365 days;

    address oracleMiddlewareAddress = address(Deployer.deployOracleMiddleware(address(proxyAdmin), maxTrustPriceAge));

    vm.stopBroadcast();

    updateJson(".oracles.middleware", oracleMiddlewareAddress);
  }
}
