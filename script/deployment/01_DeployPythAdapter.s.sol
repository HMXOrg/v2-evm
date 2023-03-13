// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { PythAdapter } from "@hmx/oracle/PythAdapter.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

contract DeployPythAdapter is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address pythAddress = getJsonAddress(".oracle.pyth");
    address pythAdapterAddress = address(new PythAdapter(IPyth(pythAddress)));

    vm.stopBroadcast();

    updateJson(".oracle.pythAdapter", pythAdapterAddress);
  }
}
