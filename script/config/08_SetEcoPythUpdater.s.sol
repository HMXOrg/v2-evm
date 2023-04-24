// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";

contract SetEcoPythUpdater is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    EcoPyth ecoPyth = EcoPyth(getJsonAddress(".oracle.ecoPyth"));

    ecoPyth.setUpdater(getJsonAddress(".handlers.bot"), true);
    ecoPyth.setUpdater(getJsonAddress(".handlers.crossMargin"), true);
    ecoPyth.setUpdater(getJsonAddress(".handlers.limitTrade"), true);
    ecoPyth.setUpdater(getJsonAddress(".handlers.liquidity"), true);
    ecoPyth.setUpdater(getJsonAddress(".handlers.marketTrade"), true);

    vm.stopBroadcast();
  }
}
