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
import { stdError } from "forge-std/StdError.sol";

/// HMX tests
import { ForkEnv } from "@hmx-test/fork/bases/ForkEnv.sol";
import { Cheats } from "@hmx-test/base/Cheats.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";

contract GetAumWithFundingFeeDebt_ForkTest is ForkEnv {
  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 125699672);
  }

  function testCorrectness_aumBeforeAfterUpgrade() external {
    uint256 aumBefore = calculator.getAUME30(true);

    vm.startPrank(ForkEnv.multiSig);
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(calculator));
    vm.stopPrank();

    uint256 aumAfter = calculator.getAUME30(true);
    assertEq(aumAfter, aumBefore + vaultStorage.hlpLiquidityDebtUSDE30());
  }
}
