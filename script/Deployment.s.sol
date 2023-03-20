// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Oracles
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { StakedGlpOracleAdapter } from "@hmx/oracles/StakedGlpOracleAdapter.sol";
import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
// Storages
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";
// Services
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
// Handlers
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { MarketTradeHandler } from "@hmx/handlers/MarketTradeHandler.sol";
// Contracts
import { Calculator } from "@hmx/contracts/Calculator.sol";
import { PLPv2 } from "@hmx/contracts/PLPv2.sol";
// Strategies
import { StakedGlpStrategy } from "@hmx/strategies/StakedGlpStrategy.sol";
// Interfaces
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { IGmxGlpManager } from "@hmx/vendors/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/vendors/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/vendors/gmx/IGmxRewardTracker.sol";

abstract contract Deployment {
  struct DeployCoreReturnVars {
    StakedGlpOracleAdapter stakedGlpOracleAdapter;
    PythAdapter pythAdapter;
    OracleMiddleware oracleMiddleware;
    ConfigStorage configStorage;
    PerpStorage perpStorage;
    VaultStorage vaultStorage;
    PLPv2 plp;
    Calculator calculator;
    LiquidityService liquidityService;
    CrossMarginService crossMarginService;
    TradeService tradeService;
    CrossMarginHandler crossMarginHandler;
    LimitTradeHandler limitTradeHandler;
    LiquidityHandler liquidityHandler;
    MarketTradeHandler marketTradeHandler;
  }

  struct DeployCoreLocalVars {
    address sGlp;
    bytes32 sGlpAssetId;
    address glpManager;
    address weth;
    uint256 minExecutionFee;
    address pyth;
    uint64 defaultOracleStaleTime;
  }

  /// @notice Deploy core contracts.
  /// @param localVars All required parameters to deploy core contracts.
  /// @return Deployed contracts.
  function deployCore(DeployCoreLocalVars memory localVars) internal returns (DeployCoreReturnVars memory) {
    DeployCoreReturnVars memory vars;

    vars.pythAdapter = new PythAdapter(IPyth(localVars.pyth));
    vars.stakedGlpOracleAdapter = new StakedGlpOracleAdapter(
      IERC20(localVars.sGlp),
      IGmxGlpManager(localVars.glpManager),
      localVars.sGlpAssetId
    );
    vars.oracleMiddleware = new OracleMiddleware();

    vars.configStorage = new ConfigStorage();
    vars.perpStorage = new PerpStorage();
    vars.vaultStorage = new VaultStorage();

    vars.plp = new PLPv2();
    vars.calculator = new Calculator(
      address(vars.oracleMiddleware),
      address(vars.vaultStorage),
      address(vars.perpStorage),
      address(vars.configStorage)
    );

    vars.liquidityService = new LiquidityService(vars.configStorage, vars.vaultStorage, vars.perpStorage);
    vars.crossMarginService = new CrossMarginService(
      address(vars.configStorage),
      address(vars.vaultStorage),
      address(vars.calculator)
    );
    vars.tradeService = new TradeService(
      address(vars.perpStorage),
      address(vars.vaultStorage),
      address(vars.configStorage)
    );

    vars.crossMarginHandler = new CrossMarginHandler(address(vars.crossMarginService), address(localVars.pyth));
    vars.limitTradeHandler = new LimitTradeHandler(
      localVars.weth,
      address(vars.tradeService),
      address(localVars.pyth),
      localVars.minExecutionFee
    );
    vars.liquidityHandler = new LiquidityHandler(
      vars.liquidityService,
      address(localVars.pyth),
      localVars.minExecutionFee
    );
    vars.marketTradeHandler = new MarketTradeHandler(address(vars.tradeService), address(localVars.pyth));

    vars.configStorage.setServiceExecutor(address(vars.liquidityService), address(vars.liquidityHandler), true);
    vars.configStorage.setServiceExecutor(address(vars.crossMarginService), address(vars.crossMarginHandler), true);
    vars.configStorage.setServiceExecutor(address(vars.tradeService), address(vars.limitTradeHandler), true);
    vars.configStorage.setServiceExecutor(address(vars.tradeService), address(vars.marketTradeHandler), true);
    vars.configStorage.setCalculator(address(vars.calculator));
    vars.configStorage.setOracle(address(vars.oracleMiddleware));
    vars.configStorage.setPLP(address(vars.plp));
    vars.configStorage.setWeth(localVars.weth);

    return vars;
  }

  struct DeployGlpStrategyLocalVars {
    address sGlp;
    address gmxRewardRouter;
    address glpFeeTracker;
    address oracleMiddleware;
    address vaultStorage;
    address keeper;
    address treasury;
    uint16 strategyBps;
  }

  /// @notice Deploy StakedGlpStrategy.
  /// @param localVars All required parameters to deploy GlpStrategy.
  /// @return Deployed contracts.
  function deployStakedGlpStrategy(DeployGlpStrategyLocalVars memory localVars) internal returns (StakedGlpStrategy) {
    VaultStorage vaultStorage = VaultStorage(localVars.vaultStorage);
    StakedGlpStrategy stakedGlpStrategy = new StakedGlpStrategy(
      ERC20(localVars.sGlp),
      IGmxRewardRouterV2(localVars.gmxRewardRouter),
      IGmxRewardTracker(localVars.glpFeeTracker),
      OracleMiddleware(localVars.oracleMiddleware),
      vaultStorage,
      localVars.keeper,
      localVars.treasury,
      localVars.strategyBps
    );

    // Set strategy on vault storage to allow the strategy to cook.
    vaultStorage.setStrategyOf(address(localVars.sGlp), address(stakedGlpStrategy), localVars.glpFeeTracker);
  }
}
