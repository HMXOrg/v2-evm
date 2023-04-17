// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Forge
import { TestBase } from "forge-std/Base.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

// interfaces
import { IWNative } from "@hmx/interfaces/IWNative.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { ILiquidityService } from "@hmx/services/interfaces/ILiquidityService.sol";
import { IPLPv2 } from "@hmx/contracts/interfaces/IPLPv2.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";
import { IOracleAdapter } from "@hmx/oracles/interfaces/IOracleAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IStrategy } from "@hmx/strategies/interfaces/IStrategy.sol";

// GMX
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";
import { IGmxRewardRouterV2 } from "@hmx/interfaces/gmx/IGmxRewardRouterV2.sol";
import { IGmxRewardTracker } from "@hmx/interfaces/gmx/IGmxRewardTracker.sol";
import { IGmxGlpManager } from "@hmx/interfaces/gmx/IGmxGlpManager.sol";

// Pyth
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";

// HMX
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { IVaultStorage } from "@hmx/storages/interfaces/IVaultStorage.sol";
import { StakedGlpStrategy } from "@hmx/strategies/StakedGlpStrategy.sol";
// OZ
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//tester
import { LiquidityTester } from "@hmx-test/testers/LiquidityTester.sol";
//deployment
import { Deployment } from "@hmx-script/Deployment.s.sol";

// Mock
import { MockWNative } from "@hmx-test/mocks/MockWNative.sol";
import { MockErc20 } from "@hmx-test/mocks/MockErc20.sol";

//Deployer
import { Deployer } from "@hmx-test/libs/Deployer.sol";

abstract contract StakedGlpStrategy_BaseForkTest is TestBase, StdAssertions, StdCheatsSafe {
  address internal constant glpManagerAddress = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
  address internal constant glpAddress = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  address internal constant sGlpAddress = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
  address internal constant gmxRewardRouterV2Address = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
  address internal constant glpFeeTrackerAddress = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
  address internal constant pythAddress = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
  //FIXME use native instead?
  address internal constant wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

  uint256 internal constant executionOrderFee = 0.0001 ether;
  bytes32 constant sGlpAssetId = "sGLP";

  // handlers
  ILiquidityHandler liquidityHandler;

  // services
  ILiquidityService liquidityService;

  // TOKENS
  IERC20 sGlp;
  IERC20 hlp;
  IPLPv2 plpV2;
  IWNative weth; //for native
  MockErc20 usdc; // decimals 6

  // ORACLES
  IGmxGlpManager internal glpManager;
  IPythAdapter internal pythAdapter;
  IOracleAdapter internal stakedGlpOracleAdapter;
  IOracleMiddleware oracleMiddleware;

  // storages
  IConfigStorage configStorage;
  IPerpStorage perpStorage;
  IVaultStorage vaultStorage;

  // calculator
  ICalculator calculator;

  IGmxRewardRouterV2 gmxRewardRouterV2;
  IGmxRewardTracker glpFeeTracker;

  IStrategy stakedGlpStrategy;

  /* Testers */
  LiquidityTester liquidityTester;

  address keeper;
  address treasury;
  address FEEVER;

  function setUp() public virtual {
    _deployContracts();

    // Config
    {
      configStorage.setOracle(address(oracleMiddleware));
      configStorage.setCalculator(address(calculator));
      configStorage.setWeth(address(weth));
      configStorage.setPLP(address(plpV2));
    }

    // Setup Storage
    {
      vaultStorage.setServiceExecutors(address(liquidityService), true);
      vaultStorage.setStrategyAllowanceOf(address(sGlp), address(stakedGlpStrategy), address(glpFeeTracker));
      perpStorage.setServiceExecutors(address(liquidityService), true);
    }

    // Set OrderExecutor
    {
      liquidityHandler.setOrderExecutor(keeper, true);
    }

    _setupAssetConfig();
    _setupLiquidityWithConfig();

    // Deploy LiquidityTester
    liquidityTester = new LiquidityTester(plpV2, vaultStorage, perpStorage, FEEVER);
  }

  function _deployContracts() private {
    keeper = makeAddr("GlpStrategyKeeper");
    treasury = makeAddr("GlpStrategyTreasury");
    FEEVER = makeAddr("FEEVER");

    sGlp = IERC20(sGlpAddress);
    gmxRewardRouterV2 = IGmxRewardRouterV2(gmxRewardRouterV2Address);
    glpManager = IGmxGlpManager(glpManagerAddress);
    glpFeeTracker = IGmxRewardTracker(glpFeeTrackerAddress);

    // Tokens
    plpV2 = Deployer.deployPLPv2();
    // weth = IWNative(new MockWNative());

    usdc = new MockErc20("USD Coin", "USDC", 6);

    vm.label(address(usdc), "USDC");
    vm.label(address(sGlp), "SGLP");
    vm.label(address(weth), "WETH");

    //deploy pythAdapter
    pythAdapter = Deployer.deployPythAdapter(pythAddress);
    //deploy stakedglpOracle
    stakedGlpOracleAdapter = Deployer.deployStakedGlpOracleAdapter(sGlp, glpManager, sGlpAssetId);

    //deploy oracleMiddleWare
    oracleMiddleware = Deployer.deployOracleMiddleware();

    // deploy configStorage
    configStorage = Deployer.deployConfigStorage();

    // deploy perpStorage
    perpStorage = Deployer.deployPerpStorage();

    // deploy vaultStorage
    vaultStorage = Deployer.deployVaultStorage();

    //deploy calculator
    calculator = Deployer.deployCalculator(
      address(oracleMiddleware),
      address(vaultStorage),
      address(perpStorage),
      address(configStorage)
    );
    //deploy liquidityService
    liquidityService = Deployer.deployLiquidityService(
      address(perpStorage),
      address(vaultStorage),
      address(configStorage)
    );
    //deploy liquidityHandler
    liquidityHandler = Deployer.deployLiquidityHandler(address(liquidityService), pythAddress, executionOrderFee);

    // Deploy GlpStrategy
    stakedGlpStrategy = Deployer.deployStakedGlpStrategy(
      sGlp,
      gmxRewardRouterV2,
      glpFeeTracker,
      oracleMiddleware,
      vaultStorage,
      keeper,
      treasury,
      1000 // 10% of reinvest
    );
  }

  function _setupLiquidityWithConfig() private {
    // Setup Liquidity Config
    // Assuming no deposit and withdraw fee.
    configStorage.setLiquidityConfig(
      IConfigStorage.LiquidityConfig({
        depositFeeRateBPS: 30, // 0.3%
        withdrawFeeRateBPS: 30, // 0.3%
        maxPLPUtilizationBPS: 8000, // 80%
        plpTotalTokenWeight: 0,
        plpSafetyBufferBPS: 2000, // 20%
        taxFeeRateBPS: 50, // 0.5%
        flashLoanFeeRateBPS: 0, //
        dynamicFeeEnabled: true,
        enabled: true
      })
    );

    // Add sGLP as a liquidity token
    address[] memory _tokens = new address[](2);
    _tokens[0] = address(sGlpAddress);
    _tokens[1] = address(usdc);

    IConfigStorage.PLPTokenConfig[] memory _plpTokenConfig = new IConfigStorage.PLPTokenConfig[](_tokens.length);

    _plpTokenConfig[0] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.95 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.05 * 1e18
    });
    _plpTokenConfig[1] = _buildAcceptedPLPTokenConfig({
      _targetWeight: 0.05 * 1e18,
      _bufferLiquidity: 0,
      _maxWeightDiff: 0.95 * 1e18
    });

    configStorage.addOrUpdateAcceptedToken(_tokens, _plpTokenConfig);
  }

  function _setupAssetConfig() private {
    // Set AssetConfig for sGlp
    IConfigStorage.AssetConfig memory _assetConfig = IConfigStorage.AssetConfig({
      tokenAddress: sGlpAddress,
      assetId: sGlpAssetId,
      decimals: 18,
      isStableCoin: false
    });
    configStorage.setAssetConfig(sGlpAssetId, _assetConfig);
    // Set oracle adapter for sGLP
    // Prepare assetIds
    bytes32[] memory _assetIds = new bytes32[](1);
    _assetIds[0] = sGlpAssetId;
  }

  function _buildAcceptedPLPTokenConfig(
    uint256 _targetWeight,
    uint256 _bufferLiquidity,
    uint256 _maxWeightDiff
  ) private pure returns (IConfigStorage.PLPTokenConfig memory _config) {
    _config.targetWeight = _targetWeight;
    _config.bufferLiquidity = _bufferLiquidity;
    _config.maxWeightDiff = _maxWeightDiff;
    _config.accepted = true;
    return _config;
  }
}
