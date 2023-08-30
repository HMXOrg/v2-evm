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

contract GetAumWithFundingFeeDebt_ForkTest is TestBase, Cheats, StdAssertions, StdCheatsSafe {
  address constant calculatorAddress = 0x0FdE910552977041Dc8c7ef652b5a07B40B9e006;
  ICalculator calculator = ICalculator(calculatorAddress);
  IVaultStorage vaultStorage = IVaultStorage(0x56CC5A9c0788e674f17F7555dC8D3e2F1C0313C0);

  function setUp() external {
    vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 125699672);
  }

  function testCorrectness_aumBeforeAfterUpgrade() external {
    uint256 aumBefore = calculator.getAUME30(true);

    vm.startPrank(ForkEnv.multiSig);
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(calculatorAddress));
    vm.stopPrank();

    uint256 aumAfter = calculator.getAUME30(true);
    assertEq(aumAfter, aumBefore + vaultStorage.hlpLiquidityDebtUSDE30());
  }
}
