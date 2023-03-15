// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Forge-std
import { TestBase } from "forge-std/Base.sol";
import { console } from "forge-std/console.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";

// Pyth
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { MockPyth } from "pyth-sdk-solidity/MockPyth.sol";

// Openzepline
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Libs
import { Deployer } from "@hmx-test/libs/Deployer.sol";

// Mock
import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

// Interfaces
import { IWNative } from "@hmx/interfaces/IWNative.sol";

import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IFeeCalculator } from "@hmx/contracts/interfaces/IFeeCalculator.sol";

import { IOracleAdapter } from "@hmx/oracle/interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracle/interfaces/IOracleMiddleware.sol";

import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IFeeCalculator } from "@hmx/contracts/interfaces/IFeeCalculator.sol";
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { IPythAdapter } from "@hmx/oracle/interfaces/IPythAdapter.sol";

import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { ICrossMarginHandler } from "@hmx/handlers/interfaces/ICrossMarginHandler.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { IMarketTradeHandler } from "@hmx/handlers/interfaces/IMarketTradeHandler.sol";

import { ICrossMarginService } from "@hmx/services/interfaces/ICrossMarginService.sol";
import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";
import { ILiquidationService } from "@hmx/services/interfaces/ILiquidationService.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";

import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";

import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
import { CrossMarginTester } from "@hmx-test/testers/CrossMarginTester.sol";
import { LimitOrderTester } from "@hmx-test/testers/LimitOrderTester.sol";
import { PositionTester } from "@hmx-test/testers/PositionTester.sol";
import { GlobalMarketTester } from "@hmx-test/testers/GlobalMarketTester.sol";
import { PositionTester02 } from "@hmx-test/testers/PositionTester02.sol";
import { TradeTester } from "@hmx-test/testers/TradeTester.sol";

abstract contract BaseIntTest is TestBase, StdCheatsSafe {
  /* Constants */
  uint256 internal constant DOLLAR = 1e30;
  uint256 internal constant executionOrderFee = 0.0001 ether;

  uint256 internal constant SECONDS = 1;
  uint256 internal constant MINUTES = SECONDS * 60;
  uint256 internal constant HOURS = MINUTES * 60;
  uint256 internal constant DAYS = HOURS * 24;

  address internal ALICE;
  address internal BOB;
  address internal CAROL;
  address internal DAVE;
  address internal EVE;
  address internal FEEVER;
  address internal ORDER_EXECUTOR;
  address internal BOT;

  /* CONTRACTS */
  IOracleMiddleware oracleMiddleWare;
  IConfigStorage configStorage;
  IPerpStorage perpStorage;
  IVaultStorage vaultStorage;
  ICalculator calculator;
  IFeeCalculator feeCalculator;

  // handlers
  IBotHandler botHandler;
  ICrossMarginHandler crossMarginHandler;
  ILimitTradeHandler limitTradeHandler;
  ILiquidityHandler liquidityHandler;
  IMarketTradeHandler marketTradeHandler;

  // services
  ICrossMarginService crossMarginService;
  ILiquidityService liquidityService;
  ILiquidationService liquidationService;
  ITradeService tradeService;

  // helpers
  ITradeHelper tradeHelper;

  /* TOKENS */

  //LP tokens
  ERC20 glp;
  IPLPv2 plpV2;

  MockErc20 wbtc; // decimals 8
  MockErc20 usdc; // decimals 6
  MockErc20 usdt; // decimals 6
  MockErc20 dai; // decimals 18

  IWNative weth; //for native

  /* PYTH */
  MockPyth internal pyth;
  IPythAdapter internal pythAdapter;

  /* Tester */

  CrossMarginTester crossMarginTester;
  GlobalMarketTester globalMarketTester;
  LimitOrderTester limitOrderTester;
  LiquidityTester liquidityTester;
  PositionTester positionTester;
  PositionTester02 positionTester02;
  TradeTester tradeTester;

  constructor() {
    ALICE = makeAddr("Alice");
    BOB = makeAddr("BOB");
    CAROL = makeAddr("CAROL");
    DAVE = makeAddr("DAVE");
    EVE = makeAddr("EVE");
    FEEVER = makeAddr("FEEVER");
    ORDER_EXECUTOR = makeAddr("ORDER_EXECUTOR");
    BOT = makeAddr("BOT");

    /* DEPLOY PART */
    // deploy MOCK weth
    weth = IWNative(new MockWNative());

    pyth = new MockPyth(60, 1);

    pythAdapter = IPythAdapter(Deployer.deployContractWithArguments("PythAdapter", abi.encode(pyth)));

    // deploy stakedGLPOracleAdapter

    // deploy oracleMiddleWare
    oracleMiddleWare = Deployer.deployOracleMiddleware(address(pythAdapter));

    // deploy configStorage
    configStorage = Deployer.deployConfigStorage();

    // deploy perpStorage
    perpStorage = Deployer.deployPerpStorage();

    // deploy vaultStorage
    vaultStorage = Deployer.deployVaultStorage();

    // Tokens
    // deploy plp
    plpV2 = Deployer.deployPLPv2();

    wbtc = new MockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = new MockErc20("DAI Stablecoin", "DAI", 18);
    usdc = new MockErc20("USD Coin", "USDC", 6);
    usdt = new MockErc20("USD Tether", "USDT", 6);

    // deploy calculator
    calculator = Deployer.deployCalculator(
      address(oracleMiddleWare),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );

    // deploy fee calculator
    feeCalculator = Deployer.deployFeeCalculator(address(vaultStorage), address(configStorage));

    // deploy handler and service
    tradeHelper = Deployer.deployTradeHelper(address(perpStorage), address(vaultStorage), address(configStorage));

    liquidityService = Deployer.deployLiquidityService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );
    liquidationService = Deployer.deployLiquidationService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage),
      address(tradeHelper)
    );
    crossMarginService = Deployer.deployCrossMarginService(
      address(configStorage),
      address(vaultStorage),
      address(calculator)
    );
    tradeService = Deployer.deployTradeService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage),
      address(tradeHelper)
    );

    botHandler = Deployer.deployBotHandler(address(tradeService), address(liquidationService), address(pyth));
    crossMarginHandler = Deployer.deployCrossMarginHandler(address(crossMarginService), address(pyth));

    limitTradeHandler = Deployer.deployLimitTradeHandler(
      address(weth),
      address(tradeService),
      address(pyth),
      executionOrderFee
    );

    liquidityHandler = Deployer.deployLiquidityHandler(address(liquidityService), address(pyth), executionOrderFee);

    marketTradeHandler = Deployer.deployMarketTradeHandler(address(tradeService), address(pyth));

    // testers

    crossMarginTester = new CrossMarginTester(vaultStorage, perpStorage, address(crossMarginHandler));
    globalMarketTester = new GlobalMarketTester(perpStorage);
    limitOrderTester = new LimitOrderTester(limitTradeHandler);
    liquidityTester = new LiquidityTester(plpV2, vaultStorage, perpStorage, FEEVER);
    positionTester = new PositionTester(perpStorage, vaultStorage, oracleMiddleWare);
    positionTester02 = new PositionTester02(perpStorage);

    address[] memory interestTokens = new address[](1);
    // TODO fix this
    interestTokens[0] = address(0);
    tradeTester = new TradeTester(
      vaultStorage,
      perpStorage,
      address(limitTradeHandler),
      address(marketTradeHandler),
      interestTokens
    );
    /* Setup part */
    // Setup ConfigStorage
    {
      configStorage.setOracle(address(oracleMiddleWare));
      configStorage.setCalculator(address(calculator));
      configStorage.setFeeCalculator(address(feeCalculator));
      tradeHelper.reloadConfig(); // @TODO: refresh config storage address here, may remove later
      tradeService.reloadConfig(); // @TODO: refresh config storage address here, may remove later
      liquidationService.reloadConfig(); // @TODO: refresh config storage address here, may remove later

      // Set whitelists for executors
      configStorage.setServiceExecutor(address(crossMarginService), address(crossMarginHandler), true);
      configStorage.setServiceExecutor(address(tradeService), address(marketTradeHandler), true);
      configStorage.setServiceExecutor(address(liquidityService), address(liquidityHandler), true);

      configStorage.setWeth(address(weth));
      configStorage.setPLP(address(plpV2));
    }

    // Setup VaultStorage
    {
      vaultStorage.setServiceExecutors(address(crossMarginService), true);
      vaultStorage.setServiceExecutors(address(tradeService), true);
      vaultStorage.setServiceExecutors(address(tradeHelper), true);
      vaultStorage.setServiceExecutors(address(liquidityService), true);
      vaultStorage.setServiceExecutors(address(liquidationService), true);
      vaultStorage.setServiceExecutors(address(feeCalculator), true);
    }

    // Setup PerpStorage
    {
      perpStorage.setServiceExecutors(address(crossMarginService), true);
      perpStorage.setServiceExecutors(address(tradeService), true);
      perpStorage.setServiceExecutors(address(tradeHelper), true);
      perpStorage.setServiceExecutors(address(liquidityService), true);
      perpStorage.setServiceExecutors(address(liquidationService), true);
    }

    // Setup Bot Handler
    {
      address[] memory _positionManagers = new address[](2);
      _positionManagers[0] = address(this);
      _positionManagers[1] = BOT;

      // set Tester as position managers
      botHandler.setPositionManagers(_positionManagers, true);
    }

    // Setup Limit Trade Handler
    {
      limitTradeHandler.setOrderExecutor(address(this), true);
    }
  }
}
