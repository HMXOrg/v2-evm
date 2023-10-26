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
    vm.createSelectFork(vm.envString("ARBITRUM_ONE_FORK"), 143862285);

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
      market: address(ForkEnv.gmxV2WbtcUsdcMarket),
      longToken: address(ForkEnv.wbtc),
      longTokenAmount: 0.01 * 1e8,
      shortToken: address(ForkEnv.usdc),
      shortTokenAmount: 0,
      minMarketTokens: 0,
      gasLimit: 1_000_000
    });
    IRebalanceHLPv2Service.DepositParams[] memory depositParams = new IRebalanceHLPv2Service.DepositParams[](1);
    depositParams[0] = depositParam;

    uint256 beforeTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 beforeAum = ForkEnv.calculator.getAUME30(false);
    uint256 beforeTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    uint256 beforeWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Wrap some ETHs for execution fee
    IWNative(address(ForkEnv.weth)).deposit{ value: executionFee * depositParams.length }();
    // Approve rebalanceService to spend WETH
    ForkEnv.weth.approve(address(rebalanceService), type(uint256).max);
    // Execute deposits
    bytes32[] memory gmxDepositOrderKeys = rebalanceService.executeDeposits(depositParams, executionFee);

    uint256 afterTvl = ForkEnv.calculator.getHLPValueE30(false);
    uint256 afterAum = ForkEnv.calculator.getAUME30(false);
    uint256 afterTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    uint256 afterWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Assert the following conditions:
    // 1. TVL should remains the same.
    // 2. AUM should remains the same.
    // 3. 0.01 WBTC should be on-hold.
    // 4. pullToken should return zero.
    // 5. afterTotalWbtc should be decreased by 0.01 WBTC
    // 6. beforeWbtc should be 0.01 more than afterWbtc.
    assertEq(beforeTvl, afterTvl, "tvl must remains the same");
    assertEq(beforeAum, afterAum, "aum must remains the same");
    assertEq(0.01 * 1e8, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0.01 WBTC should be on-hold");
    assertEq(0, ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc + 0.01 * 1e8, beforeTotalWbtc, "afterTotalWbtc should be decreased by 0.01 WBTC");
    assertEq(beforeWbtc - afterWbtc, 0.01 * 1e8, "wbtcBefore should be 0.01 more than wbtcAfter");

    // GMXv2 Keeper comes and execute the deposit order
    address[] memory realtimeFeedTokens = new address[](3);
    // Index token
    realtimeFeedTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd;
    // Long token
    realtimeFeedTokens[1] = address(ForkEnv.wbtc);
    // Short token
    realtimeFeedTokens[2] = address(ForkEnv.usdc);
    bytes[] memory realtimeFeedData = new bytes[](3);
    // Index token
    realtimeFeedData[0] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Long token
    realtimeFeedData[1] = abi.encode(344234240000000000000000000, 344264600000000000000000000);
    // Short token
    realtimeFeedData[2] = abi.encode(999900890000000000000000, 1000148200000000000000000);

    uint256 beforeGmBtcTotal = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.gmxV2WbtcUsdcMarket));
    uint256 beforeGmBtc = ForkEnv.gmxV2WbtcUsdcMarket.balanceOf(address(ForkEnv.vaultStorage));
    beforeTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    beforeWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

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

    uint256 afterGmBtcTotal = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.gmxV2WbtcUsdcMarket));
    uint256 afterGmBtc = ForkEnv.gmxV2WbtcUsdcMarket.balanceOf(address(ForkEnv.vaultStorage));
    afterTotalWbtc = ForkEnv.vaultStorage.totalAmount(address(ForkEnv.wbtc));
    afterWbtc = ForkEnv.wbtc.balanceOf(address(ForkEnv.vaultStorage));

    // Assert the following conditions:
    // 1. 0 WBTC should be on-hold.
    // 2. pullToken should return zero.
    // 3. totalWBtcAfter should decrease by 0.01 WBTC.
    // 4. wbtcBefore should remain the same.
    // 5. totalWbtcAfter should match wbtcBefore.
    // 6. gmBtcTotalAfter should more than gmBtcTotalBefore.
    // 7. gmBtcAfter should more than gmBtcBefore.
    // 8. gmBtcAfter should match with gmBtcTotalAfter.
    assertEq(0, ForkEnv.vaultStorage.hlpLiquidityOnHold(address(ForkEnv.wbtc)), "0 WBTC should be on-hold");
    assertEq(0, ForkEnv.vaultStorage.pullToken(address(ForkEnv.wbtc)), "pullToken should return zero");
    assertEq(afterTotalWbtc, beforeTotalWbtc - 0.01 * 1e8, "totalWbtcAfter should decrease by 0.01 WBTC");
    assertEq(beforeWbtc, afterWbtc, "wbtcBefore should remains the same");
    assertEq(afterWbtc, afterTotalWbtc, "total[WBTC] should match wbtcAfter");
    assertTrue(afterGmBtcTotal > beforeGmBtcTotal, "gmBtcTotalAfter should more than gmBtcTotalBefore");
    assertTrue(afterGmBtc > beforeGmBtc, "gmBtcAfter should more than gmBtcBefore");
    assertEq(afterGmBtc, afterGmBtcTotal, "gmBtcAfter should match with gmBtcTotalAfter");
  }
}
