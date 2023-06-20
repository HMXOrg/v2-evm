// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { console } from "forge-std/console.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";

contract GetEquity is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address leanPyth = getJsonAddress(".oracles.ecoPyth");
    CrossMarginHandler(payable(getJsonAddress(".handlers.crossMargin"))).setPyth(leanPyth);
    vm.stopBroadcast();
  }
}
