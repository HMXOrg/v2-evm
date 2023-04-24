// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { LeanPyth } from "@hmx/oracles/LeanPyth.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

contract DeployLeanPyth is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address leanPythAddress = address(new LeanPyth(getJsonAddress(".oracle.pyth")));

    vm.stopBroadcast();

    updateJson(".oracle.leanPyth", leanPythAddress);
  }
}
