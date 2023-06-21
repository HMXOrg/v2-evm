// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
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
