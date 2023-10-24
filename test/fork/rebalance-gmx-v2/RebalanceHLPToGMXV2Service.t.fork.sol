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
import { IRebalanceHLPToGMXV2Service } from "@hmx/services/interfaces/IRebalanceHLPToGMXV2Service.sol";

contract RebalanceHLPToGMXV2Service_ForkTest is ForkEnv {
  IRebalanceHLPToGMXV2Service rebalanceService;
  address gmxExchangeRouter = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8;
  address depositVault = 0xF89e77e8Dc11691C9e8757e84aaFbCD8A67d7A55;
  address depositHandler = 0x9Dc4f12Eb2d8405b499FB5B8AF79a5f64aB8a457;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 141887486);

    rebalanceService = Deployer.deployRebalanceHLPToGMXV2Service(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.vaultStorage),
      address(ForkEnv.configStorage),
      gmxExchangeRouter,
      depositVault,
      depositHandler,
      10000
    );

    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Deployer.upgrade("VaultStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.vaultStorage));
    vm.stopPrank();

    vm.startPrank(ForkEnv.configStorage.owner());
    vaultStorage.setServiceExecutors(address(rebalanceService), true);
    configStorage.setServiceExecutor(address(rebalanceService), address(address(this)), true);
    vm.stopPrank();
  }

  function testCorrectness_executeDeposit() external {
    IRebalanceHLPToGMXV2Service.DepositParams memory depositParam;
    depositParam.market = 0x47c031236e19d024b42f8AE6780E44A573170703; // BTCUSD
    depositParam.longToken = address(ForkEnv.wbtc);
    depositParam.longTokenAmount = 0.01 * 1e8;
    depositParam.shortToken = address(ForkEnv.usdc);
    depositParam.shortTokenAmount = 0;
    depositParam.minMarketTokens = 0;
    depositParam.executionFee = 0.01 ether;

    IRebalanceHLPToGMXV2Service.DepositParams[] memory depositParams = new IRebalanceHLPToGMXV2Service.DepositParams[](
      1
    );
    depositParams[0] = depositParam;

    rebalanceService.executeDeposits(depositParams);
  }
}
