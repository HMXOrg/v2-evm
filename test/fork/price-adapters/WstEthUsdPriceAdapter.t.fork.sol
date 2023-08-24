// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { WstEthUsdPriceAdapter } from "@hmx/oracles/adapters/WstEthUsdPriceAdapter.sol";

contract WstEthUsdPriceAdapter_ForkTest is TestBase, Cheats, StdAssertions, StdCheatsSafe {
  address internal constant EXT01_EXECUTOR = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;

  WstEthUsdPriceAdapter internal wstEthUsdPriceAdapter;

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 113073035);
  }
}
