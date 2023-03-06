// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Config
import { Config } from "@config/Config.sol";
// Forge
import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
// HMX
import { GlpStrategy } from "@hmx/strategies/GlpStrategy.sol";
import { IGmxRewardRouterV2 } from "@hmx/vendors/gmx/IGmxRewardRouterV2.sol";
import { Deployment } from "@hmx-script/Deployment.s.sol";
import { BaseTest, IConfigStorage, LiquidityHandler } from "@hmx-test/base/BaseTest.sol";
// OZ
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Pyth
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

abstract contract GlpStrategy_BaseForkTest is Config, Deployment, TestBase, StdAssertions, StdCheatsSafe {
  IGmxRewardRouterV2 gmxRewardRouterV2;
  ERC20 stkGlp;

  GlpStrategy glpStrategy;
  address keeper;
  address treasury;

  ERC20 plp;
  LiquidityHandler liquidityHandler;

  function setUp() public virtual {
    // Assigned addresses
    keeper = makeAddr("GlpStrategyKeeper");
    treasury = makeAddr("GlpStrategyTreasury");

    // Deploy core contracts
    DeployCoreLocalVars memory deployCoreLocalVars = DeployCoreLocalVars({
      pyth: pythAddress,
      defaultOracleStaleTime: 300,
      minExecutionFee: 0,
      stkGlp: stkGlpAddress,
      glpManager: glpManagerAddress,
      weth: wethAddress
    });
    DeployCoreReturnVars memory deployedCore = deployCore(deployCoreLocalVars);

    // Setup Liquidity Config
    // Assuming no deposit and withdraw fee.
    deployedCore.configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        plpTotalTokenWeight: 0,
        plpSafetyBufferThreshold: 0.8 ether,
        taxFeeRateBPS: 0,
        flashLoanFeeRateBPS: 0,
        maxPLPUtilizationBPS: 10000,
        depositFeeRateBPS: 300,
        withdrawFeeRateBPS: 300,
        dynamicFeeEnabled: false,
        enabled: true
      })
    );

    // Setup Liquidity Handler
    deployedCore.liquidityHandler.setOrderExecutor(keeper, true);

    // Deploy GlpStrategy
    DeployGlpStrategyLocalVars memory deployGlpStrategyLocalVars = DeployGlpStrategyLocalVars({
      stkGlp: stkGlpAddress,
      gmxRewardRouter: gmxRewardRouterV2Address,
      glpFeeTracker: glpFeeTrackerAddress,
      oracleMiddleware: address(deployedCore.oracleMiddleware),
      vaultStorage: address(deployedCore.vaultStorage),
      keeper: keeper,
      treasury: treasury,
      // Assuming charging 10% for the fee
      strategyBps: 1000
    });
    glpStrategy = deployGlpStrategy(deployGlpStrategyLocalVars);

    // Add stkGLP as a liquidity token
    address[] memory _tokens = new address[](1);
    _tokens[0] = stkGlpAddress;
    IConfigStorage.PLPTokenConfig[] memory _configs = new IConfigStorage.PLPTokenConfig[](1);
    _configs[0] = IConfigStorage.PLPTokenConfig({
      targetWeight: 10000,
      bufferLiquidity: 0,
      maxWeightDiff: 0,
      accepted: true
    });
    deployedCore.configStorage.addOrUpdateAcceptedToken(_tokens, _configs);

    // Assign states
    gmxRewardRouterV2 = IGmxRewardRouterV2(gmxRewardRouterV2Address);
    stkGlp = ERC20(stkGlpAddress);

    plp = ERC20(deployedCore.plp);
    liquidityHandler = deployedCore.liquidityHandler;
  }
}
