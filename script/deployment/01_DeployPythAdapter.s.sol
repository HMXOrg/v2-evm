// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPythAdapter is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    address pythAddress = getJsonAddress(".oracles.pyth");
    address pythAdapterAddress = address(Deployer.deployPythAdapter(address(proxyAdmin), pythAddress));

    vm.stopBroadcast();

    updateJson(".oracles.pythAdapter", pythAdapterAddress);
  }
}
