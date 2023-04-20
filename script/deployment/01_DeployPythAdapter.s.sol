// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

contract DeployPythAdapter is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address pythAddress = getJsonAddress(".oracles.pyth");
    address pythAdapterAddress = address(new PythAdapter(pythAddress));

    vm.stopBroadcast();

    updateJson(".oracles.pythAdapter", pythAdapterAddress);
  }
}
