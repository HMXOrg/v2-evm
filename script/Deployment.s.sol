// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Oracles
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { GlpOracleAdapter } from "@hmx/oracles/GlpOracleAdapter.sol";
import { PythAdapter } from "@hmx/oracles/PythAdapter.sol";
import { OracleMiddleware } from "@hmx/oracles/OracleMiddleware.sol";
// Storages
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
// Strategies
import { GlpStrategy } from "@hmx/strategies/GlpStrategy.sol";
// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGmxGlpManager } from "@hmx/vendors/gmx/IGmxGlpManager.sol";

abstract contract Deployment {
  struct DeployReturnVars {
    GlpOracleAdapter glpOracleAdapter;
    PythAdapter pythAdapter;
    OracleMiddleware oracleMiddleware;
    ConfigStorage configStorage;
    PerpStorage perpStorage;
    VaultStorage vaultStorage;
    Calculator calculator;
    LiquidityService liquidityService;
    CrossMarginService crossMarginService;
    TradeService tradeService;
    CrossMarginHandler crossMarginHandler;
    LimitTradeHandler limitTradeHandler;
    LiquidityHandler liquidityHandler;
    MarketTradeHandler marketTradeHandler;
    GlpStrategy glpStrategy;
  }

  struct DeployLocalVars {
    address stkGlp;
    address glpManager;
    address weth;
    uint256 minExecutionFee;
    IPyth pyth;
    uint64 defaultOracleStaleTime;
  }

  function deploy(DeployLocalVars memory localVars) internal returns (DeployReturnVars memory) {
    DeployReturnVars memory vars;

    vars.pythAdapter = new PythAdapter(localVars.pyth);
    vars.glpOracleAdapter = new GlpOracleAdapter(IERC20(localVars.stkGlp), IGmxGlpManager(localVars.glpManager));
    vars.oracleMiddleware = new OracleMiddleware();

    vars.configStorage = new ConfigStorage();
    vars.perpStorage = new PerpStorage();
    vars.vaultStorage = new VaultStorage();

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

    // TODO: Configure permissions between these contracts.

    return vars;
  }
}
