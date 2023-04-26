// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { HMX } from "@hmx/tokens/HMX.sol";

contract DeployHMXToken_ETH is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address hmxAddress = address(new HMX(false));
    vm.stopBroadcast();

    updateJson(".tokens.hmx_eth", hmxAddress);
  }
}
