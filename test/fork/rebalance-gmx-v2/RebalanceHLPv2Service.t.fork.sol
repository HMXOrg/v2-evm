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
import { MockArbSys } from "@hmx-test/mocks/MockArbSys.sol";
import { MockGmxV2Oracle } from "@hmx-test/mocks/MockGmxV2Oracle.sol";

/// HMX
import { IWNative } from "@hmx/interfaces/IWNative.sol";
import { IRebalanceHLPv2Service } from "@hmx/services/interfaces/IRebalanceHLPv2Service.sol";
import { IGmxV2Oracle } from "@hmx/interfaces/gmx-v2/IGmxV2Oracle.sol";

contract RebalanceHLPv2Service_ForkTest is ForkEnv {
  IRebalanceHLPv2Service rebalanceService;

  function setUp() external {
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 141894190);

    // Mock ArbSys
    MockArbSys arbSys = new MockArbSys();
    vm.etch(0x0000000000000000000000000000000000000064, address(arbSys).code);

    // Mock GmxV2Oracle
    MockGmxV2Oracle gmxV2Oracle = new MockGmxV2Oracle();
    vm.etch(ForkEnv.gmxV2DepositHandler.oracle(), address(gmxV2Oracle).code);

    rebalanceService = Deployer.deployRebalanceHLPv2Service(
      address(ForkEnv.proxyAdmin),
      address(ForkEnv.weth),
      address(ForkEnv.vaultStorage),
      address(ForkEnv.configStorage),
      address(ForkEnv.gmxV2ExchangeRouter),
      ForkEnv.gmxV2DepositVault,
      address(ForkEnv.gmxV2DepositHandler),
      10000
    );

    vm.startPrank(ForkEnv.proxyAdmin.owner());
    Deployer.upgrade("VaultStorage", address(ForkEnv.proxyAdmin), address(ForkEnv.vaultStorage));
    Deployer.upgrade("Calculator", address(ForkEnv.proxyAdmin), address(ForkEnv.calculator));
    vm.stopPrank();

    vm.startPrank(ForkEnv.configStorage.owner());
    vaultStorage.setServiceExecutors(address(rebalanceService), true);
    vaultStorage.setServiceExecutors(address(this), true); // For testing pullToken
    configStorage.setServiceExecutor(address(rebalanceService), address(address(this)), true);
    vm.stopPrank();

    // Grant required roles
    vm.startPrank(ForkEnv.gmxV2Timelock);
    ForkEnv.gmxV2RoleStore.grantRole(address(this), keccak256(abi.encode("ORDER_KEEPER")));
    vm.stopPrank();

    vm.label(address(rebalanceService), "RebalanceHLPv2Service");
  }

  function testCorrectness_executeDeposit() external {
    // Wrap small ETHs for execution fee
    uint256 executionFee = 0.001 ether;

    // Preps
    IRebalanceHLPv2Service.DepositParams memory depositParam = IRebalanceHLPv2Service.DepositParams({
      market: ForkEnv.gmxV2WbtcUsdcMarket,
      longToken: address(ForkEnv.wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(ForkEnv.usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    uint256 beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 beforeAum = ForkEnv.calculator.getAUME30(false);

    // Wrap some ETHs for execution fee
    IWNative(address(ForkEnv.weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    ForkEnv.weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 afterAum = ForkEnv.calculator.getAUME30(false);

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    // 3. 0.01 WBTC should be on-hold.
    // 4. pullToken should return zero
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");
    assertEq(0.01 * 1e8, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0.01 WBTC should be on-hold");
    assertEq(0, ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), "pullToken should return zero");

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](2);
    realtimeFeedTokens[0] = address(ForkEnv.wbtc);
    realtimeFeedTokens[1] = address(ForkEnv.usdc);
    bytes[] memory realtimeFeedData = new bytes[](2);
    realtimeFeedData[0] = abi.encode(34_100 * 1e8);
    realtimeFeedData[1] = abi.encode(1e8);

    ForkEnv.gmxV2DepositHandler.executeDeposit(
      gmxDepositOrderKeys[0],
      IGmxV2Oracle.SetPricesParams({
        signerInfo: 0,
        tokens: new address[](0),
        compactedMinOracleBlockNumbers: new uint256[](0),
        compactedMaxOracleBlockNumbers: new uint256[](0),
        compactedOracleTimestamps: new uint256[](0),
        compactedDecimals: new uint256[](0),
        compactedMinPrices: new uint256[](0),
        compactedMinPricesIndexes: new uint256[](0),
        compactedMaxPrices: new uint256[](0),
        compactedMaxPricesIndexes: new uint256[](0),
        signatures: new bytes[](0),
        priceFeedTokens: new address[](0),
        realtimeFeedTokens: realtimeFeedTokens,
        realtimeFeedData: realtimeFeedData
      })
    );
  }
}
