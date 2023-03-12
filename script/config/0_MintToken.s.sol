// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

// for local only
contract MintToken is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    MockErc20 token = MockErc20(getJsonAddress(".tokens.usdt"));
    token.mint(0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a, 10_000_000 * 1e6);

    vm.stopBroadcast();
  }
}
