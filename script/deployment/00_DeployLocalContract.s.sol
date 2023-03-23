// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { LeanPyth } from "@hmx/oracle/LeanPyth.sol";

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { PythAdapter } from "@hmx/oracle/PythAdapter.sol";

import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";

// for local only
contract DeployLocalContract is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address pythAddress = address(new LeanPyth());
    address nativeAddress = address(new MockWNative());

    vm.stopBroadcast();

    updateJson(".oracle.pyth", pythAddress);
    updateJson(".tokens.weth", nativeAddress);
  }
}
