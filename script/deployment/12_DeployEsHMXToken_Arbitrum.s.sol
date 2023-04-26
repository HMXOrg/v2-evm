// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { EsHMX } from "@hmx/tokens/EsHMX.sol";

contract DeployEsHMXToken_Arbitrum is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address esHmxAddress = address(new EsHMX(true));
    vm.stopBroadcast();

    updateJson(".tokens.esHmx", esHmxAddress);
  }
}
