// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";

import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

// for local only
contract DeployLocalContract is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    address nativeAddress = address(new MockWNative());
    address wbtc = address(new MockErc20("Wrapped Bitcoin", "WBTC", 8));
    address dai = address(new MockErc20("DAI Stablecoin", "DAI", 18));
    address usdc = address(new MockErc20("USD Coin", "USDC", 6));
    address usdt = address(new MockErc20("USD Tether", "USDT", 6));
    address glp = address(new MockErc20("GLP", "GLP", 18));

    vm.stopBroadcast();

    updateJson(".tokens.weth", nativeAddress);
    updateJson(".tokens.wbtc", wbtc);
    updateJson(".tokens.dai", dai);
    updateJson(".tokens.usdc", usdc);
    updateJson(".tokens.usdt", usdt);
    updateJson(".tokens.sglp", glp);
  }
}
