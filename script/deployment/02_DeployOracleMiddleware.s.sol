// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";

import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";

contract DeployOracleMiddleware is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address pythAdapterAddress = getJsonAddress(".oracle.pythAdapter");
    address oracleMiddlewareAddress = address(new OracleMiddleware(IOracleAdapter(pythAdapterAddress)));

    vm.stopBroadcast();

    updateJson(".oracle.middleware", oracleMiddlewareAddress);
  }
}
