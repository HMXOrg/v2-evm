// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { EcoPyth } from "@hmx/oracles/EcoPyth.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

contract DeployLeanPyth is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address ecoPythAddress = address(new EcoPyth());

    vm.stopBroadcast();

    updateJson(".oracles.ecoPyth", ecoPythAddress);
  }
}
