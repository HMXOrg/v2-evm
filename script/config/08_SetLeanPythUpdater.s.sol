// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { LeanPyth } from "@hmx/oracles/LeanPyth.sol";

contract SetLeanPythUpdater is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    LeanPyth leanPyth = LeanPyth(getJsonAddress(".oracle.leanPyth"));

    leanPyth.setUpdater(getJsonAddress(".handlers.bot"), true);
    leanPyth.setUpdater(getJsonAddress(".handlers.crossMargin"), true);
    leanPyth.setUpdater(getJsonAddress(".handlers.limitTrade"), true);
    leanPyth.setUpdater(getJsonAddress(".handlers.liquidity"), true);
    leanPyth.setUpdater(getJsonAddress(".handlers.marketTrade"), true);

    vm.stopBroadcast();
  }
}
