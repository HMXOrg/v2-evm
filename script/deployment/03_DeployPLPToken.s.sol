// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployPLPToken is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    vm.startBroadcast(deployerPrivateKey);

    address plpAddress = address(Deployer.deployPLPv2(address(proxyAdmin)));

    vm.stopBroadcast();

    updateJson(".tokens.hlp", plpAddress);
  }
}
