// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";

import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";

// for local only
contract DeployLocalContract is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address pythAddress = address(new MockPyth(60, 1));
    address nativeAddress = address(new MockWNative());

    vm.stopBroadcast();

    updateJson(".oracles.pyth", pythAddress);
    updateJson(".tokens.weth", nativeAddress);
  }
}
